import SwiftUI
import LLMkit

// MARK: - API-key credentials

/// Inline credential entry for any provider whose only secret is a single
/// API key (most cloud providers).
struct APIKeyCredentialView: View {
    let entry: ProviderEntry
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var catalog: ProviderCatalog

    @State private var inputKey: String = ""
    @State private var isVerifying = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var hasKey: Bool {
        _ = catalog.configurationRevision
        return APIKeyManager.shared.hasAPIKey(forProvider: entry.id.rawValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            credentialHeader(title: "API key", systemImage: "key.fill")
            if hasKey {
                HStack {
                    Text("Stored in Keychain")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("••••••••").foregroundColor(.secondary)
                    Button("Remove", role: .destructive) { removeKey() }
                }
            } else {
                SecureField("Paste your API key", text: $inputKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    if let url = entry.signupURL {
                        Link(destination: url) {
                            Label("Get API key", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                    }
                    Spacer()
                    Button {
                        verifyAndSave()
                    } label: {
                        HStack(spacing: 4) {
                            if isVerifying { ProgressView().controlSize(.small) }
                            Text("Verify and save")
                        }
                    }
                    .disabled(inputKey.isEmpty || isVerifying)
                }
            }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(alertMessage) }
    }

    private func verifyAndSave() {
        isVerifying = true
        Task {
            let result = await ProviderVerifier.verify(entry: entry, apiKey: inputKey)
            await MainActor.run {
                isVerifying = false
                if result.isValid {
                    APIKeyManager.shared.saveAPIKey(inputKey, forProvider: entry.id.rawValue)
                    aiService.refreshKeyStateForCurrentProvider()
                    NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
                    catalog.markChanged()
                    inputKey = ""
                } else {
                    alertMessage = result.errorMessage ?? "Verification failed"
                    showAlert = true
                }
            }
        }
    }

    private func removeKey() {
        APIKeyManager.shared.deleteAPIKey(forProvider: entry.id.rawValue)
        aiService.refreshKeyStateForCurrentProvider()
        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
        catalog.markChanged()
    }
}

// MARK: - Ollama credentials

struct OllamaCredentialView: View {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var catalog: ProviderCatalog

    @State private var baseURL: String = UserDefaults.standard.string(forKey: "ollamaBaseURL") ?? "http://localhost:11434"
    @State private var isEditing = false
    @State private var isChecking = false
    @State private var connected = false
    @State private var models: [OllamaModel] = []
    @State private var selectedModel: String = UserDefaults.standard.string(forKey: "ollamaSelectedModel") ?? "mistral"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            credentialHeader(title: "Server", systemImage: "server.rack")
            if isEditing {
                HStack {
                    TextField("Base URL", text: $baseURL)
                        .textFieldStyle(.roundedBorder)
                    Button("Save") {
                        aiService.updateOllamaBaseURL(baseURL)
                        isEditing = false
                        check()
                    }
                }
            } else {
                HStack {
                    Text("Endpoint: \(baseURL)")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                    Spacer()
                    Button("Edit") { isEditing = true }
                    Button {
                        baseURL = "http://localhost:11434"
                        aiService.updateOllamaBaseURL(baseURL)
                        check()
                    } label: { Image(systemName: "arrow.counterclockwise") }
                        .help("Reset to default")
                }
            }

            HStack(spacing: 8) {
                if isChecking {
                    ProgressView().controlSize(.small)
                    Text("Checking…").foregroundColor(.secondary)
                } else if connected {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text("Connected").foregroundColor(.secondary)
                } else {
                    Circle().fill(Color.red).frame(width: 8, height: 8)
                    Text("Disconnected").foregroundColor(.secondary)
                }
                Spacer()
                Button("Refresh") { check() }.disabled(isChecking)
            }
            .font(.system(size: 12))

            if !models.isEmpty {
                Divider()
                Picker("Default model", selection: $selectedModel) {
                    ForEach(models) { model in Text(model.name).tag(model.name) }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedModel) { _, new in
                    aiService.updateSelectedOllamaModel(new)
                }
            }
        }
        .onAppear { check() }
    }

    private func check() {
        isChecking = true
        aiService.checkOllamaConnection { ok in
            connected = ok
            if ok {
                Task {
                    let fetched = await aiService.fetchOllamaModels()
                    await MainActor.run {
                        models = fetched
                        isChecking = false
                        catalog.markChanged()
                        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
                    }
                }
            } else {
                models = []
                isChecking = false
                catalog.markChanged()
                NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
            }
        }
    }
}

// MARK: - Local CLI credentials

struct LocalCLICredentialView: View {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var catalog: ProviderCatalog

    @State private var command: String = ""
    @State private var timeout: Double = LocalCLIService.defaultTimeoutSeconds
    @State private var isSyncing = false

    private static let timeoutOptions: [Double] = [15, 30, 45, 60, 90, 120, 180, 300]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                credentialHeader(title: "Command", systemImage: "terminal")
                Spacer()
                Menu("Load template") {
                    ForEach(LocalCLITemplate.allCases) { template in
                        Button(template.displayName) {
                            aiService.loadLocalCLITemplate(template)
                            sync()
                            catalog.markChanged()
                            NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
                        }
                    }
                }
            }

            TextEditor(text: $command)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 100)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .onChange(of: command) { _, new in
                    guard !isSyncing else { return }
                    if new != aiService.localCLICommandTemplate {
                        aiService.updateLocalCLICommandTemplate(new)
                        catalog.markChanged()
                        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
                    }
                }

            Picker("Timeout", selection: $timeout) {
                ForEach(Self.timeoutOptions, id: \.self) { Text("\(Int($0))s").tag($0) }
            }
            .pickerStyle(.menu)
            .onChange(of: timeout) { _, new in
                aiService.updateLocalCLITimeoutSeconds(new)
            }

            Text("Environment variables: VOICEINK_SYSTEM_PROMPT, VOICEINK_USER_PROMPT, VOICEINK_FULL_PROMPT. VoiceInk also writes VOICEINK_FULL_PROMPT to stdin.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear { sync() }
    }

    private func sync() {
        isSyncing = true
        command = aiService.localCLICommandTemplate
        timeout = aiService.localCLITimeoutSeconds
        DispatchQueue.main.async { isSyncing = false }
    }
}

// MARK: - Custom OpenAI-compatible credentials

struct CustomProviderCredentialView: View {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var catalog: ProviderCatalog

    @State private var inputKey: String = ""
    @State private var isVerifying = false
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var hasKey: Bool {
        _ = catalog.configurationRevision
        return APIKeyManager.shared.hasAPIKey(forProvider: ProviderID.custom.rawValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            credentialHeader(title: "OpenAI-compatible endpoint", systemImage: "gearshape.2.fill")

            TextField("API endpoint URL", text: $aiService.customBaseURL,
                      prompt: Text("e.g. https://api.openai.com/v1/chat/completions"))
                .textFieldStyle(.roundedBorder)
            TextField("Model name", text: $aiService.customModel,
                      prompt: Text("e.g. gpt-5.4, claude-opus-4-7"))
                .textFieldStyle(.roundedBorder)

            if hasKey {
                HStack {
                    Text("API key stored").font(.system(size: 12)).foregroundColor(.secondary)
                    Spacer()
                    Button("Remove", role: .destructive) {
                        APIKeyManager.shared.deleteAPIKey(forProvider: ProviderID.custom.rawValue)
                        aiService.refreshKeyStateForCurrentProvider()
                        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
                        catalog.markChanged()
                    }
                }
            } else {
                SecureField("API key", text: $inputKey)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button {
                        verify()
                    } label: {
                        HStack(spacing: 4) {
                            if isVerifying { ProgressView().controlSize(.small) }
                            Text("Verify and save")
                        }
                    }
                    .disabled(aiService.customBaseURL.isEmpty
                              || aiService.customModel.isEmpty
                              || inputKey.isEmpty
                              || isVerifying)
                }
            }
        }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(alertMessage) }
    }

    private func verify() {
        guard let baseURL = URL(string: aiService.customBaseURL) else {
            alertMessage = "Invalid base URL"
            showAlert = true
            return
        }
        let model = aiService.customModel
        let candidate = inputKey
        isVerifying = true
        Task {
            let r = await OpenAILLMClient.verifyAPIKey(baseURL: baseURL, apiKey: candidate, model: model)
            await MainActor.run {
                isVerifying = false
                if r.isValid {
                    APIKeyManager.shared.saveAPIKey(candidate, forProvider: ProviderID.custom.rawValue)
                    aiService.refreshKeyStateForCurrentProvider()
                    NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
                    catalog.markChanged()
                    inputKey = ""
                } else {
                    alertMessage = r.errorMessage ?? "Verification failed"
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Local model lists (Whisper, Parakeet)

/// Shows the model catalog for a local STT provider, with each variant
/// rendered through the existing `ModelCardView` so download/delete/set-
/// default flows are identical to the AI Models tab. Whisper additionally
/// gets an "Import .bin" button that mirrors `ModelManagementView`.
struct LocalModelsCredentialView: View {
    let entry: ProviderEntry
    @EnvironmentObject private var whisperModelManager: WhisperModelManager
    @EnvironmentObject private var fluidAudioModelManager: FluidAudioModelManager
    @EnvironmentObject private var transcriptionModelManager: TranscriptionModelManager
    @EnvironmentObject private var catalog: ProviderCatalog
    @ObservedObject private var warmupCoordinator = WhisperModelWarmupCoordinator.shared

    @State private var isShowingDeleteAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var deleteActionClosure: () -> Void = {}

    /// Curated set of model names worth recommending to first-time users.
    /// Surfaced here (next to download buttons) instead of as a separate
    /// filter pill on the AI Models tab — the recommendation lives where
    /// the action lives.
    private static let recommendedNames: Set<String> = [
        "ggml-base.en",
        "parakeet-tdt-0.6b-v2",
        "ggml-large-v3-turbo-q5_0",
        "whisper-large-v3-turbo"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            credentialHeader(title: "Models", systemImage: "square.and.arrow.down.fill")
            modelsList
            if entry.id == .whisper {
                importWhisperButton
            }
        }
        .alert(isPresented: $isShowingDeleteAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                primaryButton: .destructive(Text("Delete"), action: deleteActionClosure),
                secondaryButton: .cancel()
            )
        }
    }

    private var modelsList: some View {
        VStack(spacing: 10) {
            ForEach(sortedModels, id: \.id) { model in
                modelRow(for: model)
            }
        }
    }

    @ViewBuilder
    private func modelRow(for model: any TranscriptionModel) -> some View {
        let isWarming = (model as? WhisperModel).map { whisperModel in
            warmupCoordinator.isWarming(modelNamed: whisperModel.name)
        } ?? false

        VStack(alignment: .leading, spacing: 4) {
            if Self.recommendedNames.contains(model.name) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .semibold))
                    Text("Recommended")
                        .font(.system(size: 10, weight: .semibold))
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.18))
                .foregroundColor(.accentColor)
                .cornerRadius(4)
                .padding(.leading, 4)
            }

            ModelCardView(
                model: model,
                fluidAudioModelManager: fluidAudioModelManager,
                transcriptionModelManager: transcriptionModelManager,
                isDownloaded: whisperModelManager.availableModels.contains { $0.name == model.name },
                isCurrent: transcriptionModelManager.currentTranscriptionModel?.name == model.name,
                downloadProgress: whisperModelManager.downloadProgress,
                modelURL: whisperModelManager.availableModels.first { $0.name == model.name }?.url,
                isWarming: isWarming,
                deleteAction: { presentDeleteAlert(for: model) },
                setDefaultAction: {
                    Task { transcriptionModelManager.setDefaultTranscriptionModel(model) }
                },
                downloadAction: {
                    if let whisperModel = model as? WhisperModel {
                        Task { await whisperModelManager.downloadModel(whisperModel) }
                    }
                },
                editAction: nil
            )
        }
    }

    private var sortedModels: [any TranscriptionModel] {
        // Push recommended variants to the top of the list — the rest keep
        // the registry's natural order.
        let pool = filteredModels
        let recommended = pool.filter { Self.recommendedNames.contains($0.name) }
        let others = pool.filter { !Self.recommendedNames.contains($0.name) }
        return recommended + others
    }

    private var importWhisperButton: some View {
        HStack(spacing: 8) {
            Button(action: presentImportPanel) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.down")
                    Text("Import local .bin model…")
                        .font(.system(size: 12, weight: .semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(CardBackground(isSelected: false))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)

            InfoTip(
                "Add a custom fine-tuned whisper model. Select the downloaded .bin file.",
                learnMoreURL: "https://tryvoiceink.com/docs/custom-local-whisper-models"
            )
            .help("Read more about custom local models")
        }
    }

    private var filteredModels: [any TranscriptionModel] {
        let targetProvider: ModelProvider
        switch entry.id {
        case .whisper:     targetProvider = .whisper
        case .fluidAudio:  targetProvider = .fluidAudio
        default:           return []
        }
        return transcriptionModelManager.allAvailableModels.filter {
            $0.provider == targetProvider && transcriptionModelManager.isAvailableOnCurrentOS($0)
        }
    }

    private func presentDeleteAlert(for model: any TranscriptionModel) {
        if let downloaded = whisperModelManager.availableModels.first(where: { $0.name == model.name }) {
            alertTitle = "Delete Model"
            alertMessage = "Are you sure you want to delete '\(downloaded.name)'?"
            deleteActionClosure = {
                Task { await whisperModelManager.deleteModel(downloaded) }
            }
            isShowingDeleteAlert = true
        }
    }

    private func presentImportPanel() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.init(filenameExtension: "bin")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.resolvesAliases = true
        panel.title = "Select a Whisper ggml .bin model"
        if panel.runModal() == .OK, let url = panel.url {
            Task { @MainActor in
                await whisperModelManager.importWhisperModel(from: url)
            }
        }
    }
}

// MARK: - Built-in / no setup

/// Card body for providers that need no setup — they are baked into the OS.
struct BuiltInProviderInfoView: View {
    let entry: ProviderEntry
    @EnvironmentObject private var transcriptionModelManager: TranscriptionModelManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            credentialHeader(title: "Installation", systemImage: "checkmark.seal.fill")
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("No setup required")
                        .font(.system(size: 13, weight: .medium))
                    Text("Built into the operating system. Pick it as the active model in the AI Models tab.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            if let appleModel = appleSpeechModel {
                HStack {
                    Text(appleModel.displayName).font(.system(size: 12))
                    Spacer()
                    if transcriptionModelManager.currentTranscriptionModel?.name == appleModel.name {
                        Text("Active")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                    } else {
                        Button("Set as active") {
                            Task { transcriptionModelManager.setDefaultTranscriptionModel(appleModel) }
                        }
                        .controlSize(.small)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private var appleSpeechModel: (any TranscriptionModel)? {
        transcriptionModelManager.allAvailableModels.first {
            $0.provider == .nativeApple
        }
    }
}

// MARK: - Helpers

@ViewBuilder
fileprivate func credentialHeader(title: String, systemImage: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: systemImage)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
    }
}

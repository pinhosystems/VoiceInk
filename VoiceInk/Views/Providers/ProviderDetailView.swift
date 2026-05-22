import SwiftUI
import LLMkit

/// Right-pane detail for a single provider in the Providers tab. Renders:
///   - a header with capability badges
///   - credential entry whose shape is driven by `entry.credentialKind`
///   - an STT settings card (if the provider offers STT)
///   - an LLM settings card (if the provider offers LLM)
///
/// Per-modality settings panels are deliberately small for now: only xAI
/// exposes tuning knobs on the STT side. Other providers' cards make it
/// explicit that there is no provider-specific setting to tweak yet.
struct ProviderDetailView: View {
    let entry: ProviderEntry
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var catalog: ProviderCatalog

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                credentialsSection
                if entry.capabilities.contains(.stt) {
                    sttSection
                }
                if entry.capabilities.contains(.llm) {
                    llmSection
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(entry.displayName)
                    .font(.title2.bold())
                ForEach(entry.capabilities.sorted(), id: \.self) { cap in
                    CapabilityBadge(capability: cap)
                }
                Spacer()
                if catalog.isConfigured(entry) {
                    HStack(spacing: 4) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("Configured").font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            Text(capabilityDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var credentialsSection: some View {
        switch entry.credentialKind {
        case .apiKey:
            APIKeyCredentialView(entry: entry)
        case .baseURL:
            OllamaCredentialView()
        case .commandTemplate:
            LocalCLICredentialView()
        case .baseURLAndModel:
            CustomProviderCredentialView()
        }
    }

    private var sttSection: some View {
        ProviderSectionCard(title: "STT settings", systemImage: "waveform") {
            sttSettingsContent
        }
    }

    @ViewBuilder
    private var sttSettingsContent: some View {
        switch entry.id {
        case .xai:
            XAIAdvancedSettingsView()
        default:
            Text("No provider-specific STT settings.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var llmSection: some View {
        ProviderSectionCard(title: "LLM settings", systemImage: "bubble.left.and.bubble.right") {
            Text("Pick the active LLM model and prompt in the Enhancement tab.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var capabilityDescription: String {
        let stt = entry.capabilities.contains(.stt)
        let llm = entry.capabilities.contains(.llm)
        if stt && llm { return "Speech-to-text and LLM enhancement." }
        if stt        { return "Speech-to-text only." }
        if llm        { return "LLM enhancement only." }
        return ""
    }
}

// MARK: - Section card

struct ProviderSectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.headline)
            }
            VStack(alignment: .leading, spacing: 8) {
                content()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
    }
}

// MARK: - API-key credentials

private struct APIKeyCredentialView: View {
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
        ProviderSectionCard(title: "Credentials", systemImage: "key.fill") {
            if hasKey {
                HStack {
                    Text("API key configured")
                    Spacer()
                    Text("••••••••").foregroundColor(.secondary)
                    Button("Remove", role: .destructive) { removeKey() }
                }
            } else {
                SecureField("API key", text: $inputKey)
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

private struct OllamaCredentialView: View {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var catalog: ProviderCatalog

    @State private var baseURL: String = UserDefaults.standard.string(forKey: "ollamaBaseURL") ?? "http://localhost:11434"
    @State private var isEditing = false
    @State private var isChecking = false
    @State private var connected = false
    @State private var models: [OllamaModel] = []
    @State private var selectedModel: String = UserDefaults.standard.string(forKey: "ollamaSelectedModel") ?? "mistral"

    var body: some View {
        ProviderSectionCard(title: "Credentials", systemImage: "server.rack") {
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
                    Text("Server: \(baseURL)")
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

private struct LocalCLICredentialView: View {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var catalog: ProviderCatalog

    @State private var command: String = ""
    @State private var timeout: Double = LocalCLIService.defaultTimeoutSeconds
    @State private var isSyncing = false

    private static let timeoutOptions: [Double] = [15, 30, 45, 60, 90, 120, 180, 300]

    var body: some View {
        ProviderSectionCard(title: "Credentials", systemImage: "terminal") {
            HStack {
                Text("Command")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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

private struct CustomProviderCredentialView: View {
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
        ProviderSectionCard(title: "Credentials", systemImage: "key.fill") {
            TextField("API endpoint URL", text: $aiService.customBaseURL,
                      prompt: Text("e.g. https://api.openai.com/v1/chat/completions"))
                .textFieldStyle(.roundedBorder)
            TextField("Model name", text: $aiService.customModel,
                      prompt: Text("e.g. gpt-5.4, claude-opus-4-7"))
                .textFieldStyle(.roundedBorder)

            if hasKey {
                HStack {
                    Text("API key set")
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

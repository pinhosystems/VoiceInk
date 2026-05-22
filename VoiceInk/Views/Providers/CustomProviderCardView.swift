import SwiftUI
import LLMkit

/// Accordion card for a single user-defined `CustomProvider`. Mirrors the
/// visual rhythm of `ProviderCardView` (icon tile, header strip, status
/// pill, chevron) but the body is an inline editor: every field writes
/// back to `CustomProviderManager` on change, and the API key is stored
/// via `APIKeyManager.saveCustomModelAPIKey(forModelId:)` so the existing
/// STT pipeline finds it under the same Keychain identifier.
///
/// One record can opt into STT, LLM, or both. The fields for each branch
/// only appear when its toggle is on, so the form stays compact while
/// supporting the full union shape.
struct CustomProviderCardView: View {
    let provider: CustomProvider
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var catalog: ProviderCatalog

    @State private var draft: CustomProvider
    @State private var apiKeyInput: String = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var confirmDelete = false

    init(provider: CustomProvider, isExpanded: Bool, onToggleExpand: @escaping () -> Void) {
        self.provider = provider
        self.isExpanded = isExpanded
        self.onToggleExpand = onToggleExpand
        _draft = State(initialValue: provider)
    }

    private var hasKey: Bool {
        _ = catalog.configurationRevision
        return APIKeyManager.shared.getCustomModelAPIKey(forModelId: provider.id) != nil
    }

    private var isConfigured: Bool {
        // STT-capable: any key counts. LLM-capable: key + selected as active
        // (or auto-selectable) gates `connectedProviders`. For the card
        // status pill, "has key + at least one capability checked" is enough.
        guard provider.offersSTT || provider.offersLLM else { return false }
        return hasKey
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerStrip
            if isExpanded {
                Divider().padding(.top, 14)
                editorBody
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(isSelected: false))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture { onToggleExpand() }
        .alert("Error", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: { Text(alertMessage) }
        .alert("Delete custom provider?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                CustomProviderManager.shared.remove(id: provider.id)
                if aiService.selectedCustomLLMProviderID == provider.id {
                    aiService.selectedCustomLLMProviderID = nil
                }
                catalog.markChanged()
                NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(provider.name) and its credentials will be removed. The STT model attached to this provider will disappear from AI Models.")
        }
    }

    private var headerStrip: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "gearshape.2.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(provider.name.isEmpty ? "Unnamed custom" : provider.name)
                        .font(.title3.bold())
                    ForEach(provider.capabilities.sorted(), id: \.self) { cap in
                        CapabilityBadge(capability: cap)
                    }
                    Spacer()
                    statusPill
                    chevron
                }
                Text(provider.summary.isEmpty ? "User-defined OpenAI-compatible endpoint." : provider.summary)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConfigured ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(isConfigured ? "Configured" : "Needs setup")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background((isConfigured ? Color.green : Color.orange).opacity(0.12))
        .cornerRadius(10)
    }

    private var chevron: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(6)
            .background(Circle().fill(Color.secondary.opacity(0.08)))
    }

    private var editorBody: some View {
        VStack(alignment: .leading, spacing: 14) {
            identitySection
            capabilitiesSection
            if draft.offersSTT { sttFieldsSection }
            if draft.offersLLM { llmFieldsSection }
            apiKeySection
            HStack {
                Spacer()
                Button("Delete provider", role: .destructive) {
                    confirmDelete = true
                }
                .controlSize(.small)
            }
        }
    }

    private var identitySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Identity", systemImage: "person.text.rectangle")
            TextField("Name (shown in pickers)", text: $draft.name,
                      prompt: Text("e.g. Local Llama gateway"))
                .textFieldStyle(.roundedBorder)
                .onChange(of: draft.name) { _, _ in persist() }
            TextField("Description (optional)", text: $draft.summary,
                      prompt: Text("Short note shown on the card"))
                .textFieldStyle(.roundedBorder)
                .onChange(of: draft.summary) { _, _ in persist() }
        }
    }

    private var capabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Capabilities", systemImage: "checklist")
            Toggle(isOn: $draft.offersSTT) {
                Text("Speech-to-text")
            }
            .toggleStyle(.switch)
            .onChange(of: draft.offersSTT) { _, _ in persist() }

            Toggle(isOn: $draft.offersLLM) {
                Text("LLM enhancement")
            }
            .toggleStyle(.switch)
            .onChange(of: draft.offersLLM) { _, _ in persist() }
        }
    }

    private var sttFieldsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "STT endpoint", systemImage: "waveform")
            TextField("Transcription URL", text: $draft.sttEndpointURL,
                      prompt: Text("e.g. https://api.openai.com/v1/audio/transcriptions"))
                .textFieldStyle(.roundedBorder)
                .onChange(of: draft.sttEndpointURL) { _, _ in persist() }
            TextField("STT model name", text: $draft.sttModelName,
                      prompt: Text("e.g. whisper-1"))
                .textFieldStyle(.roundedBorder)
                .onChange(of: draft.sttModelName) { _, _ in persist() }
            Toggle(isOn: $draft.isMultilingual) {
                HStack(spacing: 4) {
                    Text("Multilingual")
                    InfoTip("When on, the language picker offers every supported language. When off, the model is treated as English-only.")
                }
            }
            .toggleStyle(.switch)
            .onChange(of: draft.isMultilingual) { _, _ in persist() }
        }
    }

    private var llmFieldsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "LLM endpoint", systemImage: "bubble.left.and.bubble.right")
            TextField("Chat completions URL", text: $draft.llmEndpointURL,
                      prompt: Text("e.g. https://api.openai.com/v1/chat/completions"))
                .textFieldStyle(.roundedBorder)
                .onChange(of: draft.llmEndpointURL) { _, _ in persist() }
            TextField("LLM model name", text: $draft.llmModelName,
                      prompt: Text("e.g. gpt-5.4, claude-opus-4-7"))
                .textFieldStyle(.roundedBorder)
                .onChange(of: draft.llmModelName) { _, _ in persist() }
        }
    }

    private var apiKeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title: "Credentials", systemImage: "key.fill")
            if hasKey {
                HStack {
                    Text("API key stored")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("••••••••").foregroundColor(.secondary)
                    Button("Remove", role: .destructive) { removeKey() }
                }
            } else {
                SecureField("API key", text: $apiKeyInput)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button {
                        verifyAndSave()
                    } label: {
                        Text("Verify and save")
                    }
                    .disabled(!canVerify)
                }
            }
        }
    }

    private var canVerify: Bool {
        guard !apiKeyInput.isEmpty else { return false }
        if draft.offersLLM {
            guard !draft.llmEndpointURL.isEmpty, !draft.llmModelName.isEmpty else { return false }
            return true
        }
        if draft.offersSTT {
            guard !draft.sttEndpointURL.isEmpty, !draft.sttModelName.isEmpty else { return false }
            return true
        }
        return false
    }

    private func sectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Actions

    private func persist() {
        CustomProviderManager.shared.update(draft)
        catalog.markChanged()
        if aiService.selectedCustomLLMProviderID == draft.id {
            aiService.syncFromActiveCustomLLM()
        }
    }

    private func verifyAndSave() {
        let candidate = apiKeyInput
        // For LLM-capable customs, verify via OpenAI-compatible client.
        if draft.offersLLM {
            guard let url = URL(string: draft.llmEndpointURL) else {
                alertMessage = "Invalid LLM endpoint URL"
                showAlert = true
                return
            }
            Task {
                let r = await OpenAILLMClient.verifyAPIKey(baseURL: url, apiKey: candidate, model: draft.llmModelName)
                await MainActor.run {
                    if r.isValid {
                        storeKeyAndNotify(candidate)
                    } else {
                        alertMessage = r.errorMessage ?? "Verification failed"
                        showAlert = true
                    }
                }
            }
        } else {
            // STT-only: skip remote probing (no cheap STT verify path), just store.
            storeKeyAndNotify(candidate)
        }
    }

    private func storeKeyAndNotify(_ key: String) {
        APIKeyManager.shared.saveCustomModelAPIKey(key, forModelId: draft.id)
        apiKeyInput = ""
        if aiService.selectedProvider == .custom {
            aiService.syncFromActiveCustomLLM()
        } else if draft.offersLLM && aiService.selectedCustomLLMProviderID == nil {
            // Auto-select the freshly configured custom as the active LLM
            // when none was selected yet.
            aiService.selectedCustomLLMProviderID = draft.id
        }
        catalog.markChanged()
        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
    }

    private func removeKey() {
        APIKeyManager.shared.deleteCustomModelAPIKey(forModelId: draft.id)
        if aiService.selectedProvider == .custom {
            aiService.refreshKeyStateForCurrentProvider()
        }
        catalog.markChanged()
        NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
    }
}

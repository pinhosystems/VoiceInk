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
                .contentShape(Rectangle())
                .onTapGesture { onToggleExpand() }
            if isExpanded {
                Divider().padding(.top, 14)
                editorBody
                    .padding(.top, 14)
                    .transition(
                        .asymmetric(
                            insertion: .opacity.animation(.easeInOut(duration: 0.22).delay(0.05)),
                            removal: .opacity.animation(.easeInOut(duration: 0.12))
                        )
                    )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(isSelected: false))
        .cornerRadius(12)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isExpanded)
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
        Image(systemName: "chevron.down")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .padding(6)
            .background(Circle().fill(Color.secondary.opacity(0.08)))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }

    private var editorBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            identityBlock
            sttBlock
            llmBlock
            credentialsBlock
            deleteFooter
        }
    }

    // MARK: - Identity

    private var identityBlock: some View {
        EditorBlock(title: "Identity", systemImage: "person.text.rectangle", tint: .secondary) {
            FieldLabel("Name", help: "Shown in the Providers list and in Enhancement's Custom picker.")
            TextField("", text: $draft.name, prompt: Text("e.g. Local Llama gateway"))
                .textFieldStyle(.roundedBorder)
                .onChange(of: draft.name) { _, _ in persist() }

            FieldLabel("Description", help: "Optional. Appears on the card below the name.")
            TextField("", text: $draft.summary, prompt: Text("Short note about this provider"))
                .textFieldStyle(.roundedBorder)
                .onChange(of: draft.summary) { _, _ in persist() }
        }
    }

    // MARK: - STT block

    private var sttBlock: some View {
        EditorBlock(
            title: "Speech-to-text",
            systemImage: "waveform",
            tint: .blue,
            headerTrailing: {
                AnyView(
                    Toggle("", isOn: $draft.offersSTT)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: draft.offersSTT) { _, _ in persist() }
                )
            }
        ) {
            if draft.offersSTT {
                FieldLabel("Transcription URL")
                TextField("", text: $draft.sttEndpointURL,
                          prompt: Text("https://api.openai.com/v1/audio/transcriptions"))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: draft.sttEndpointURL) { _, _ in persist() }

                FieldLabel("STT model")
                TextField("", text: $draft.sttModelName, prompt: Text("e.g. whisper-1"))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: draft.sttModelName) { _, _ in persist() }

                Toggle(isOn: $draft.isMultilingual) {
                    HStack(spacing: 4) {
                        Text("Multilingual")
                            .font(.system(size: 12))
                        InfoTip("On: language picker offers every supported language. Off: model is treated as English-only.")
                    }
                }
                .toggleStyle(.switch)
                .onChange(of: draft.isMultilingual) { _, _ in persist() }
                .padding(.top, 2)
            } else {
                Text("Turn on to expose this provider as a transcription model in AI Models.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - LLM block

    private var llmBlock: some View {
        EditorBlock(
            title: "LLM enhancement",
            systemImage: "bubble.left.and.bubble.right",
            tint: .purple,
            headerTrailing: {
                AnyView(
                    Toggle("", isOn: $draft.offersLLM)
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .onChange(of: draft.offersLLM) { _, _ in persist() }
                )
            }
        ) {
            if draft.offersLLM {
                FieldLabel("Chat completions URL")
                TextField("", text: $draft.llmEndpointURL,
                          prompt: Text("https://api.openai.com/v1/chat/completions"))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: draft.llmEndpointURL) { _, _ in persist() }

                FieldLabel("LLM model")
                TextField("", text: $draft.llmModelName,
                          prompt: Text("e.g. gpt-5.4, claude-opus-4-7"))
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: draft.llmModelName) { _, _ in persist() }
            } else {
                Text("Turn on to use this provider for enhancement in the Enhancement tab.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Credentials block

    private var credentialsBlock: some View {
        EditorBlock(title: "Credentials", systemImage: "key.fill", tint: .orange) {
            if hasKey {
                storedKeyControls
            } else {
                FieldLabel("API key", help: "Same key is used for STT and LLM when both are enabled.")
                SecureField("", text: $apiKeyInput, prompt: Text("Paste the secret here"))
                    .textFieldStyle(.roundedBorder)
                HStack {
                    if !canVerify {
                        Text(verifyDisabledHint)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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

    /// Controls shown once a key is stored. The user can still re-verify the
    /// stored credential against whichever capabilities and endpoints are
    /// currently enabled — important because users often save with STT only
    /// and later enable LLM (or vice-versa); without this they would have
    /// to delete and re-paste the key to confirm the new endpoint works.
    @ViewBuilder
    private var storedKeyControls: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("API key stored")
                    .font(.system(size: 12))
            }
            Spacer()
            Text("••••••••").foregroundColor(.secondary)
            Button("Re-verify", action: reverifyStoredKey)
                .disabled(!canReverify)
            Button("Remove", role: .destructive) { removeKey() }
        }
        if !canReverify {
            Text(verifyDisabledHint)
                .font(.caption)
                .foregroundColor(.secondary)
        }

        Divider()

        FieldLabel("Replace API key", help: "Paste a new secret here to overwrite the stored one.")
        SecureField("", text: $apiKeyInput, prompt: Text("Paste a new secret"))
            .textFieldStyle(.roundedBorder)
        HStack {
            Spacer()
            Button {
                verifyAndSave()
            } label: {
                Text("Verify and replace")
            }
            .disabled(apiKeyInput.isEmpty || !canVerify)
        }
    }

    // MARK: - Delete footer

    private var deleteFooter: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Button("Delete provider", role: .destructive) {
                    confirmDelete = true
                }
                .controlSize(.small)
            }
            .padding(.top, 10)
        }
    }

    /// True when the user has typed a key AND the enabled capabilities have
    /// the URL+model pair needed to actually verify the call.
    private var canVerify: Bool {
        guard !apiKeyInput.isEmpty else { return false }
        return endpointsReady
    }

    /// Same gating as `canVerify` minus the input-field check — used when a
    /// key is already stored so the user can re-verify without retyping.
    private var canReverify: Bool { endpointsReady }

    private var endpointsReady: Bool {
        guard draft.offersSTT || draft.offersLLM else { return false }
        if draft.offersLLM, draft.llmEndpointURL.isEmpty || draft.llmModelName.isEmpty {
            return false
        }
        if draft.offersSTT, draft.sttEndpointURL.isEmpty || draft.sttModelName.isEmpty {
            return false
        }
        return true
    }

    private var verifyDisabledHint: String {
        if !draft.offersSTT && !draft.offersLLM {
            return "Enable Speech-to-text or LLM enhancement first."
        }
        if draft.offersLLM, draft.llmEndpointURL.isEmpty || draft.llmModelName.isEmpty {
            return "Fill in the LLM endpoint and model."
        }
        if draft.offersSTT, draft.sttEndpointURL.isEmpty || draft.sttModelName.isEmpty {
            return "Fill in the STT endpoint and model."
        }
        return ""
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

    /// Re-runs the LLM verification against the *stored* key — used when the
    /// user enabled a new capability after the original save and needs to
    /// confirm the new endpoint resolves correctly.
    private func reverifyStoredKey() {
        guard let stored = APIKeyManager.shared.getCustomModelAPIKey(forModelId: draft.id),
              !stored.isEmpty else {
            alertMessage = "No stored key to re-verify."
            showAlert = true
            return
        }
        guard draft.offersLLM else {
            // STT-only verification has no cheap probe path; treat the stored
            // key as already-good and tell the user.
            alertMessage = "STT-only providers are not probed — saving the key is enough."
            showAlert = true
            return
        }
        guard let url = URL(string: draft.llmEndpointURL) else {
            alertMessage = "Invalid LLM endpoint URL"
            showAlert = true
            return
        }
        Task {
            let r = await OpenAILLMClient.verifyAPIKey(baseURL: url, apiKey: stored, model: draft.llmModelName)
            await MainActor.run {
                if r.isValid {
                    alertMessage = "Connection OK."
                } else {
                    alertMessage = r.errorMessage ?? "Verification failed"
                }
                showAlert = true
            }
        }
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

// MARK: - Visual building blocks

/// Visually distinct sub-section inside a custom provider card. Each block
/// carries an icon + title row, an optional trailing control (used for the
/// STT/LLM capability toggles), and a tinted rounded body so STT, LLM and
/// Credentials are easy to tell apart at a glance.
private struct EditorBlock<Content: View>: View {
    let title: String
    let systemImage: String
    let tint: Color
    var headerTrailing: (() -> AnyView)?
    @ViewBuilder var content: () -> Content

    init(
        title: String,
        systemImage: String,
        tint: Color,
        headerTrailing: (() -> AnyView)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self.headerTrailing = headerTrailing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(tint)
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                if let trailing = headerTrailing {
                    trailing()
                }
            }
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tint.opacity(0.22), lineWidth: 1)
        )
        .cornerRadius(10)
    }
}

/// Field label rendered above its input. Optional help text appears as a
/// secondary line so users see the constraint without hovering an InfoTip.
private struct FieldLabel: View {
    let text: String
    let help: String?

    init(_ text: String, help: String? = nil) {
        self.text = text
        self.help = help
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            if let help = help {
                Text(help)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.75))
            }
        }
    }
}

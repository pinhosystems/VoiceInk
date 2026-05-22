import SwiftUI
import UniformTypeIdentifiers

struct EnhancementSettingsView: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @EnvironmentObject private var aiService: AIService
    @State private var isEditingPrompt = false
    @State private var isShowingSettings = false
    @State private var selectedPromptForEdit: CustomPrompt?
    @State private var panelID = UUID()

    private let panelWidth: CGFloat = 400

    /// AIProviders that are LLM-capable AND have a usable credential. The
    /// historical AIProvider enum still carries STT-only providers (ElevenLabs,
    /// Deepgram, Soniox, Speechmatics, AssemblyAI) — none of them implement
    /// real chat completion, so they are excluded here just like the legacy
    /// APIKeyManagementView did.
    private static let sttOnlyLLMAliases: Set<AIProvider> = [
        .elevenLabs, .deepgram, .soniox, .speechmatics, .assemblyAI
    ]

    private var connectedLLMProviders: [AIProvider] {
        aiService.connectedProviders.filter { !Self.sttOnlyLLMAliases.contains($0) }
    }

    private enum PanelType {
        case promptEditor
        case settings
    }

    private var activePanel: PanelType? {
        if isShowingSettings { return .settings }
        if isEditingPrompt || selectedPromptForEdit != nil { return .promptEditor }
        return nil
    }

    private var isPanelOpen: Bool {
        activePanel != nil
    }

    private func openPromptPanel() {
        isShowingSettings = false
        panelID = UUID()
    }

    private func closePanel() {
        withAnimation(.smooth(duration: 0.3)) {
            isEditingPrompt = false
            selectedPromptForEdit = nil
            isShowingSettings = false
        }
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $enhancementService.isEnhancementEnabled) {
                    HStack(spacing: 4) {
                        Text("Enable Enhancement")
                        InfoTip(
                            "When ON, the transcript is post-processed by an LLM using the active Transcription Profile's writing rules. When OFF, the LLM step is skipped but the profile still controls vocabulary bias sent to the STT engine.",
                            learnMoreURL: "https://tryvoiceink.com/docs/enhancements-configuring-models"
                        )
                    }
                }
                .toggleStyle(.switch)
            } header: {
                HStack {
                    Text("General")
                    Spacer()
                    Button {
                        withAnimation(.smooth(duration: 0.3)) {
                            isEditingPrompt = false
                            selectedPromptForEdit = nil
                            isShowingSettings.toggle()
                        }
                    } label: {
                        Image(systemName: "gear")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isShowingSettings ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Enhancement settings")
                }
            }

            llmProviderSection
                .opacity(enhancementService.isEnhancementEnabled ? 1.0 : 0.8)

            Section {
                ReorderablePromptGrid(
                    selectedPromptId: enhancementService.selectedPromptId,
                    onPromptSelected: { prompt in
                        enhancementService.setActivePrompt(prompt)
                    },
                    onEditPrompt: { prompt in
                        openPromptPanel()
                        withAnimation(.smooth(duration: 0.3)) {
                            selectedPromptForEdit = prompt
                        }
                    },
                    onDeletePrompt: { prompt in
                        enhancementService.deletePrompt(prompt)
                    }
                )
                .padding(.vertical, 8)
            } header: {
                HStack {
                    Text("Transcription Profiles")
                    InfoTip("The active profile always controls vocabulary bias sent to the STT engine. Its writing rules only apply when Enhancement is enabled.")
                    Spacer()
                    Button {
                        openPromptPanel()
                        withAnimation(.smooth(duration: 0.3)) {
                            isEditingPrompt = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Add new profile")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear { resetSelectedProviderIfDisconnected() }
        .onReceive(NotificationCenter.default.publisher(for: .aiProviderKeyChanged)) { _ in
            resetSelectedProviderIfDisconnected()
        }
        .slidingPanel(isPresented: .init(
            get: { isPanelOpen },
            set: { newValue in
                if !newValue { closePanel() }
            }
        ), width: panelWidth) {
            Group {
                switch activePanel {
                case .settings:
                    EnhancementSettingsPanel(onDismiss: closePanel)
                case .promptEditor:
                    Group {
                        if let prompt = selectedPromptForEdit {
                            PromptEditorView(mode: .edit(prompt)) {
                                closePanel()
                            }
                        } else if isEditingPrompt {
                            PromptEditorView(mode: .add) {
                                closePanel()
                            }
                        }
                    }
                    .id(panelID)
                case nil:
                    EmptyView()
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    @ViewBuilder
    private var llmProviderSection: some View {
        Section {
            if connectedLLMProviders.isEmpty {
                // Keep the empty-state CTA fully interactive: a brand-new
                // install often has Enhancement turned off and zero
                // providers configured — disabling the "Open Providers"
                // button in that state would dead-end the onboarding flow.
                emptyProvidersView
            } else {
                Picker(selection: $aiService.selectedProvider) {
                    ForEach(connectedLLMProviders, id: \.self) { provider in
                        Text(provider.rawValue).tag(provider)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Provider")
                        InfoTip("Only providers configured in the Providers tab show up here.")
                    }
                }
                .pickerStyle(.menu)
                .disabled(!enhancementService.isEnhancementEnabled)

                modelControls
                    .disabled(!enhancementService.isEnhancementEnabled)

                if !enhancementService.isEnhancementEnabled {
                    Text("Provider and model are read-only while Enhancement is off — they only affect the LLM step.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("LLM")
        }
    }

    @ViewBuilder
    private var modelControls: some View {
        switch aiService.selectedProvider {
        case .openRouter:
            if aiService.availableModels.isEmpty {
                HStack {
                    Text("No models loaded").foregroundColor(.secondary)
                    Spacer()
                    Button { Task { await aiService.fetchOpenRouterModels() } } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            } else {
                HStack {
                    Picker("Model", selection: Binding(
                        get: { aiService.currentModel },
                        set: { aiService.selectModel($0) }
                    )) {
                        ForEach(aiService.availableModels, id: \.self) { Text($0).tag($0) }
                    }
                    Button { Task { await aiService.fetchOpenRouterModels() } } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        case .ollama:
            if aiService.availableModels.isEmpty {
                Text("No Ollama models found. Set the server up in Providers → Ollama.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Picker("Model", selection: Binding(
                    get: { aiService.currentModel },
                    set: { aiService.selectModel($0) }
                )) {
                    ForEach(aiService.availableModels, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
            }
        case .localCLI:
            localCLIControls
        case .custom:
            customLLMControls
        default:
            if !aiService.availableModels.isEmpty {
                Picker("Model", selection: Binding(
                    get: { aiService.currentModel },
                    set: { aiService.selectModel($0) }
                )) {
                    ForEach(aiService.availableModels, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var emptyProvidersView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("No LLM provider configured.")
                .font(.subheadline)
            Text("Open the Providers tab and add an API key, base URL, or command template.")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Open Providers") {
                NotificationCenter.default.post(
                    name: .navigateToDestination,
                    object: nil,
                    userInfo: ["destination": "Providers"]
                )
            }
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var customLLMControls: some View {
        let llmCustoms = CustomProviderManager.shared.providers(offering: .llm).filter { provider in
            APIKeyManager.shared.getCustomModelAPIKey(forModelId: provider.id) != nil
        }
        if llmCustoms.isEmpty {
            Text("No custom LLM providers configured. Add one in Providers → Custom.")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            Picker(selection: Binding(
                get: { aiService.selectedCustomLLMProviderID ?? llmCustoms.first?.id ?? UUID() },
                set: { id in
                    aiService.selectedCustomLLMProviderID = id
                }
            )) {
                ForEach(llmCustoms, id: \.id) { provider in
                    Text(provider.name).tag(provider.id)
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Custom provider")
                    InfoTip("Pick which user-defined custom LLM provider to use for enhancement. Add or edit them in Providers → Custom.")
                }
            }
            .pickerStyle(.menu)

            if let active = activeCustomLLM {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Endpoint").foregroundColor(.secondary)
                        Spacer()
                        Text(active.llmEndpointURL.isEmpty ? "—" : active.llmEndpointURL)
                            .font(.system(.caption, design: .monospaced))
                    }
                    HStack {
                        Text("Model").foregroundColor(.secondary)
                        Spacer()
                        Text(active.llmModelName.isEmpty ? "—" : active.llmModelName)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var localCLIControls: some View {
        let cliProviders = LocalCLIProviderManager.shared.configuredProviders
        if cliProviders.isEmpty {
            Text("No Local CLI provider configured. Add one in Providers.")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            Picker(selection: Binding(
                get: { aiService.selectedLocalCLIProviderID ?? cliProviders.first?.id ?? UUID() },
                set: { id in aiService.selectedLocalCLIProviderID = id }
            )) {
                ForEach(cliProviders, id: \.id) { provider in
                    Text(provider.name).tag(provider.id)
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Local CLI")
                    InfoTip("Pick which user-defined Local CLI provider to use for enhancement.")
                }
            }
            .pickerStyle(.menu)

            if let active = activeLocalCLI {
                HStack {
                    Text("Command").foregroundColor(.secondary)
                    Spacer()
                    Text(active.commandTemplate.isEmpty ? "—" : active.commandTemplate)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }

    private var activeLocalCLI: LocalCLIProvider? {
        guard let id = aiService.selectedLocalCLIProviderID else { return nil }
        return LocalCLIProviderManager.shared.provider(for: id)
    }

    private var activeCustomLLM: CustomProvider? {
        guard let id = aiService.selectedCustomLLMProviderID else { return nil }
        return CustomProviderManager.shared.provider(for: id)
    }

    private func resetSelectedProviderIfDisconnected() {
        let connected = connectedLLMProviders
        guard !connected.isEmpty else { return }
        if !connected.contains(aiService.selectedProvider),
           let fallback = connected.first {
            aiService.selectedProvider = fallback
        }
    }
}

// MARK: - Reorderable Grid
private struct ReorderablePromptGrid: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService

    let selectedPromptId: UUID?
    let onPromptSelected: (CustomPrompt) -> Void
    let onEditPrompt: ((CustomPrompt) -> Void)?
    let onDeletePrompt: ((CustomPrompt) -> Void)?

    @State private var draggingItem: CustomPrompt?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if enhancementService.customPrompts.isEmpty {
                Text("No prompts available")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                let columns = [
                    GridItem(.adaptive(minimum: 80, maximum: 100), spacing: 36)
                ]

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(enhancementService.customPrompts) { prompt in
                        prompt.promptIcon(
                            isSelected: selectedPromptId == prompt.id,
                            onTap: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    onPromptSelected(prompt)
                                }
                            },
                            onEdit: onEditPrompt,
                            onDelete: onDeletePrompt
                        )
                        .opacity(draggingItem?.id == prompt.id ? 0.3 : 1.0)
                        .scaleEffect(draggingItem?.id == prompt.id ? 1.05 : 1.0)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    draggingItem != nil && draggingItem?.id != prompt.id
                                    ? Color.accentColor.opacity(0.25)
                                    : Color.clear,
                                    lineWidth: 1
                                )
                        )
                        .animation(.easeInOut(duration: 0.15), value: draggingItem?.id == prompt.id)
                        .onDrag {
                            draggingItem = prompt
                            return NSItemProvider(object: prompt.id.uuidString as NSString)
                        }
                        .onDrop(
                            of: [UTType.text],
                            delegate: PromptDropDelegate(
                                item: prompt,
                                prompts: $enhancementService.customPrompts,
                                draggingItem: $draggingItem
                            )
                        )
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)

                HStack {
                    Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)

                    Text("Double-click to edit • Right-click for more options")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.top, 8)
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - Drop Delegate
private struct PromptDropDelegate: DropDelegate {
    let item: CustomPrompt
    @Binding var prompts: [CustomPrompt]
    @Binding var draggingItem: CustomPrompt?

    func dropEntered(info: DropInfo) {
        guard let draggingItem = draggingItem, draggingItem != item else { return }
        guard let fromIndex = prompts.firstIndex(of: draggingItem),
              let toIndex = prompts.firstIndex(of: item) else { return }

        if prompts[toIndex].id != draggingItem.id {
            withAnimation(.easeInOut(duration: 0.12)) {
                let from = fromIndex
                let to = toIndex
                prompts.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingItem = nil
        return true
    }
}

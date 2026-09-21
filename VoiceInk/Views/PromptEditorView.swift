import SwiftUI

struct PromptEditorView: View {
    enum Mode {
        case add
        case edit(CustomPrompt)
        
        static func == (lhs: Mode, rhs: Mode) -> Bool {
            switch (lhs, rhs) {
            case (.add, .add):
                return true
            case let (.edit(prompt1), .edit(prompt2)):
                return prompt1.id == prompt2.id
            default:
                return false
            }
        }
    }
    
    let mode: Mode
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var enhancementService: AIEnhancementService
    var onDismiss: (() -> Void)?
    @State private var title: String
    @State private var promptText: String
    @State private var selectedIcon: PromptIcon
    @State private var description: String
    @State private var triggerWords: [String]
    @State private var useSystemInstructions: Bool
    @State private var selectedCategory: PromptCategory
    @State private var showingIconPicker = false
    // Dictionary is a modal-only surface (no longer a routable sidebar
    // destination), so the jump-link below opens it as a self-contained
    // sheet instead of posting `.navigateToDestination`, which clamps to
    // sidebar rows and was a no-op here. Mirrors Settings → Advanced.
    @State private var isShowingDictionarySheet = false
    @State private var isShowingFinalPrompt = false
    @State private var isShowingTemplateBrowser = false

    private var isEditingPredefinedPrompt: Bool {
        if case .edit(let prompt) = mode {
            return prompt.isPredefined
        }
        return false
    }

    /// The prompt as it ships in `PredefinedPrompts`, for the restore button
    /// and the "modified" state. Nil for user-created prompts.
    private var factoryTemplate: CustomPrompt? {
        guard case .edit(let prompt) = mode, prompt.isPredefined else { return nil }
        return PredefinedPrompts.all.first { $0.id == prompt.id }
    }

    /// Whether the fields currently on screen diverge from the shipped text.
    /// Drives the restore button, so it reflects unsaved edits too.
    private var hasFactoryDivergence: Bool {
        guard let template = factoryTemplate else { return false }
        return PredefinedPromptMerger.hasUserEdits(editedPrompt(from: template), template: template)
    }

    init(mode: Mode, onDismiss: (() -> Void)? = nil) {
        self.mode = mode
        self.onDismiss = onDismiss
        switch mode {
        case .add:
            _title = State(initialValue: "")
            _promptText = State(initialValue: "")
            _selectedIcon = State(initialValue: "doc.text.fill")
            _description = State(initialValue: "")
            _triggerWords = State(initialValue: [])
            _useSystemInstructions = State(initialValue: true)
            _selectedCategory = State(initialValue: .writing)
        case .edit(let prompt):
            _title = State(initialValue: prompt.title)
            _promptText = State(initialValue: prompt.promptText)
            _selectedIcon = State(initialValue: prompt.icon)
            _description = State(initialValue: prompt.description ?? "")
            _triggerWords = State(initialValue: prompt.triggerWords)
            _useSystemInstructions = State(initialValue: prompt.useSystemInstructions)
            _selectedCategory = State(initialValue: prompt.category)
        }
    }
    
    private func dismissPanel() {
        if let onDismiss = onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text(isEditingPredefinedPrompt ? "Edit Built-in Prompt" : (mode == .add ? "New Prompt" : "Edit Prompt"))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                if isEditingPredefinedPrompt {
                    Text("Built-in")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: dismissPanel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Divider().opacity(0.5), alignment: .bottom
            )

            // Content
            promptForm

            // Footer
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { dismissPanel() }
                        .keyboardShortcut(.escape, modifiers: [])
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)

                    if hasFactoryDivergence {
                        Button("Restore Default") { confirmRestore() }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                            .help("Discard your changes and go back to the prompt VoiceInk ships with")
                    }

                    Spacer()

                    Button {
                        save()
                        dismissPanel()
                    } label: {
                        Text("Save Changes")
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(title.isEmpty || promptText.isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $isShowingDictionarySheet) {
            // Same modal pattern as Settings → Advanced: wrap the editor in
            // a NavigationStack and add a Done button, since the inner view
            // ships no close affordance of its own.
            NavigationStack {
                DictionarySettingsView(whisperPrompt: WhisperPrompt())
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                isShowingDictionarySheet = false
                            }
                        }
                    }
            }
            .frame(minWidth: 720, minHeight: 560)
        }
        .sheet(isPresented: $isShowingTemplateBrowser) {
            NavigationStack {
                PredefinedPromptsView { template in
                    apply(template)
                    isShowingTemplateBrowser = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isShowingTemplateBrowser = false }
                    }
                }
            }
        }
    }

    private func apply(_ template: TemplatePrompt) {
        title = template.title
        promptText = template.promptText
        selectedIcon = template.icon
        description = template.description
        triggerWords = template.triggerWords
        selectedCategory = template.category
    }

    // MARK: - Form

    private var promptForm: some View {
        Form {
            if isEditingPredefinedPrompt {
                Section {
                    Text("This is one of VoiceInk's built-in prompts. Edit it freely — \"Restore Default\" brings the shipped version back at any time. While it is edited, app updates to this prompt no longer apply to it.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section {
                HStack(alignment: .center, spacing: 14) {
                    Button(action: { showingIconPicker = true }) {
                        Image(systemName: selectedIcon)
                            .font(.system(size: 22))
                            .foregroundColor(.primary)
                            .frame(width: 44, height: 44)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showingIconPicker, arrowEdge: .bottom) {
                        IconPickerPopover(selectedIcon: $selectedIcon, isPresented: $showingIconPicker)
                    }

                    TextField("Prompt Name", text: $title)
                        .textFieldStyle(.roundedBorder)
                }

                TextField("Brief description", text: $description)
                    .textFieldStyle(.roundedBorder)

                Picker("Category", selection: $selectedCategory) {
                    ForEach(PromptCategory.orderedCases) { category in
                        Text(category.displayName).tag(category)
                    }
                }
            } header: {
                Text("Details")
            }

            Section {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $promptText)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 160)
                        .scrollContentBackground(.hidden)

                    if promptText.isEmpty {
                        Text("Enter your custom prompt instructions here...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }

                Toggle(isOn: $useSystemInstructions) {
                    HStack(spacing: 4) {
                        Text("Use System Template")
                        InfoTip("If enabled, your instructions are combined with a general-purpose template to improve transcription quality.\n\nDisable for full control over the AI's system prompt (for advanced users).")
                    }
                }
                .toggleStyle(.switch)

                finalPromptPreview
            } header: {
                Text("Instructions")
            }

            Section {
                TriggerWordsEditor(triggerWords: $triggerWords)
            } header: {
                HStack(spacing: 4) {
                    Text("Trigger Words")
                    InfoTip("Add words that automatically activate this prompt. For example, 'summarize', 'email', 'translate'.")
                }
            }

            if case .edit(let prompt) = mode {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(prompt.vocabularyDomains, id: \.self) { domain in
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                                    .font(.system(size: 11))
                                Text(label(for: domain))
                                    .font(.callout)
                            }
                        }

                        Text("These domains bias the STT engine and the LLM enhancement while this prompt is active.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)

                        Button {
                            isShowingDictionarySheet = true
                        } label: {
                            Label("Open Dictionary", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                    }
                } header: {
                    Text("Vocabulary Domains")
                }
            }

            if case .add = mode {
                Section {
                    Button {
                        isShowingTemplateBrowser = true
                    } label: {
                        Label("Start with Template", systemImage: "sparkles")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func label(for domain: VocabularyDomain) -> String {
        switch domain {
        case .userVocabulary:
            return "User vocabulary"
        case .technical:
            return "Technical (English)"
        case .locale(let code):
            let resolved = LocalePackRegistry.pack(for: code)?.displayName
                ?? Locale(identifier: "en").localizedString(forIdentifier: code)
                ?? code
            return "Locale: \(resolved) (\(code))"
        }
    }

    // MARK: - Final Prompt Preview

    /// Read-only view of what the LLM actually receives — for prompts using the
    /// system template, the editable text above is only the `USER_RULES` body.
    private var finalPromptPreview: some View {
        DisclosureGroup(isExpanded: $isShowingFinalPrompt) {
            ScrollView {
                Text(renderedFinalPrompt)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 220)
            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            .cornerRadius(6)

            Text("Language, vocabulary and context blocks are appended at runtime.")
                .font(.caption2)
                .foregroundColor(.secondary)
        } label: {
            Text("Final prompt")
                .font(.callout)
        }
    }

    private var renderedFinalPrompt: String {
        // The Assistant prompt's stored text is a placeholder until the user
        // edits it — the runtime builds it from `assistantMode` instead.
        if case .edit(let prompt) = mode,
           prompt.id == PredefinedPrompts.assistantPromptId,
           !hasFactoryDivergence {
            return AIPrompts.assistantMode(flags: .all)
        }
        return CustomPrompt(
            title: title,
            promptText: promptText,
            useSystemInstructions: useSystemInstructions
        ).finalPromptText()
    }

    // MARK: - Actions

    private func confirmRestore() {
        guard case .edit(let prompt) = mode, let template = factoryTemplate else { return }
        let alert = NSAlert()
        alert.messageText = "Restore Default Prompt?"
        alert.informativeText = "'\(template.title)' goes back to the text, icon and trigger words VoiceInk ships with. Your changes to it are discarded."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        enhancementService.restorePredefinedPrompt(prompt)
        dismissPanel()
    }

    /// Applies the on-screen fields to `base`, keeping the identity fields the
    /// editor never exposes. Shared by the save path and the "modified" check.
    private func editedPrompt(from base: CustomPrompt) -> CustomPrompt {
        CustomPrompt(
            id: base.id,
            title: title,
            promptText: promptText,
            isActive: base.isActive,
            icon: selectedIcon,
            description: description.isEmpty ? nil : description,
            isPredefined: base.isPredefined,
            triggerWords: triggerWords,
            useSystemInstructions: useSystemInstructions,
            vocabularyDomains: base.vocabularyDomains,
            category: selectedCategory,
            isCustomized: base.isCustomized
        )
    }

    private func save() {
        switch mode {
        case .add:
            enhancementService.addPrompt(
                title: title,
                promptText: promptText,
                icon: selectedIcon,
                description: description.isEmpty ? nil : description,
                triggerWords: triggerWords,
                useSystemInstructions: useSystemInstructions,
                category: selectedCategory
            )
        case .edit(let prompt):
            let edited = editedPrompt(from: prompt)
            // Trigger-word-only edits leave `isCustomized` false so the prompt
            // keeps receiving upstream text updates.
            let updated = factoryTemplate.map {
                edited.with(isCustomized: PredefinedPromptMerger.hasUserEdits(edited, template: $0))
            } ?? edited
            enhancementService.updatePrompt(updated)
        }
    }
}

// MARK: - Trigger Words Editor
struct TriggerWordsEditor: View {
    @Binding var triggerWords: [String]
    @State private var newTriggerWord: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Add trigger word", text: $newTriggerWord)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addTriggerWord() }

                Button(action: { addTriggerWord() }) {
                    Image(systemName: "plus.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .disabled(newTriggerWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if !triggerWords.isEmpty {
                TagLayout(alignment: .leading, spacing: 6) {
                    ForEach(triggerWords, id: \.self) { word in
                        TriggerWordItemView(word: word) {
                            triggerWords.removeAll { $0 == word }
                        }
                    }
                }
            } else {
                Text("No trigger words added")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
                    .italic()
            }
        }
    }
    
    private func addTriggerWord() {
        let trimmedWord = newTriggerWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWord.isEmpty else { return }
        
        let lowerCaseWord = trimmedWord.lowercased()
        guard !triggerWords.contains(where: { $0.lowercased() == lowerCaseWord }) else { return }
        
        triggerWords.append(trimmedWord)
        newTriggerWord = ""
    }
}

// MARK: - Trigger Word Item
struct TriggerWordItemView: View {
    let word: String
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 4) {
                Text(word)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 120, alignment: .leading)
                    .foregroundColor(.primary)
            
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.leading, 2)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Tag Layout
struct TagLayout: Layout {
    var alignment: Alignment = .leading
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var currentRowWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentRowWidth + size.width > maxWidth {
                // New row
                height += size.height + spacing
                currentRowWidth = size.width + spacing
            } else {
                // Same row
                currentRowWidth += size.width + spacing
            }
            
            if height == 0 {
                height = size.height
            }
        }
        
        return CGSize(width: maxWidth, height: height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        let maxHeight = subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += maxHeight + spacing
            }
            
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
        }
    }
}

// MARK: - Icon Picker
struct IconPickerPopover: View {
    @Binding var selectedIcon: PromptIcon
    @Binding var isPresented: Bool
    
    var body: some View {
        let columns = [
            GridItem(.adaptive(minimum: 45, maximum: 52), spacing: 14)
        ]
        
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(PromptIcon.allCases, id: \.self) { icon in
                    Button(action: {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                            selectedIcon = icon
                            isPresented = false
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedIcon == icon ? Color(NSColor.windowBackgroundColor) : Color(NSColor.controlBackgroundColor))
                                .frame(width: 52, height: 52)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(selectedIcon == icon ? Color(NSColor.separatorColor) : Color.secondary.opacity(0.2), lineWidth: selectedIcon == icon ? 2 : 1)
                                )
                            
                            Image(systemName: icon)
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .scaleEffect(selectedIcon == icon ? 1.1 : 1.0)
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selectedIcon == icon)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .frame(width: 400, height: 400)
    }
}

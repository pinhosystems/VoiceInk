import SwiftUI

/// Inline test sandbox embedded in the Enhancement screen. Lets the user paste
/// a transcript-style sentence and run it through the active prompt + provider
/// + model without having to record. Prompt selection AND prompt body
/// customization are isolated to the sandbox — provider and model stay
/// untouched, so the user can iterate prompt wording without retoggling the
/// global AI configuration.
///
/// Calls `AIEnhancementService.enhance(_:overridePrompt:)` directly so the
/// pipeline (system message, locale rules, context attachments) matches the
/// recorder. The override prompt is a synthetic, never-persisted
/// CustomPrompt cloned from the picker selection with its `promptText`
/// replaced when the user enables "Customize prompt text".
struct EnhancementTestSection: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService

    @State private var isExpanded = false
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var errorMessage: String?
    @State private var isRunning = false
    @State private var lastDuration: TimeInterval?

    @State private var testPromptId: UUID?
    @State private var overrideEnabled: Bool = false
    @State private var overridePromptText: String = ""

    private static let defaultPlaceholder = "Paste or type a transcription here, then press Run to see the LLM rewrite it with the current prompt, provider, and model."

    private static let defaultOverridePlaceholder = "Write a system prompt to test. The toggle above keeps your saved prompt safe — this text is only used for this Run."

    private var availablePrompts: [CustomPrompt] {
        enhancementService.allPrompts
    }

    private var resolvedTestPrompt: CustomPrompt? {
        if let id = testPromptId {
            return availablePrompts.first(where: { $0.id == id })
        }
        return enhancementService.activePrompt ?? availablePrompts.first
    }

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    promptPickerRow
                    overrideRow
                    inputArea
                    runRow
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }
                    if !outputText.isEmpty {
                        outputArea
                    }
                }
                .padding(.top, 6)
                .onAppear { syncDefaults() }
                .onChange(of: testPromptId) { _, _ in syncOverrideText() }
            } label: {
                HStack(spacing: 4) {
                    Text("Test enhancement")
                    InfoTip("Runs your input through the SAME pipeline VoiceInk would use after a recording — provider, model, context attachments, and locale rules. The prompt picker and prompt-text override below stay scoped to this sandbox: they do NOT touch the AI provider, the model, or your saved prompts.")
                }
            }
        } header: {
            Text("Sandbox")
        }
    }

    // MARK: - Prompt controls

    private var promptPickerRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("Prompt")
                    .font(.caption)
                    .foregroundColor(.secondary)
                InfoTip("Pick which saved prompt the test should use. The selection is local to the sandbox — your globally active prompt does not change.")
            }
            Picker("", selection: $testPromptId) {
                ForEach(availablePrompts) { prompt in
                    Text(prompt.title).tag(prompt.id as UUID?)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(availablePrompts.isEmpty)
        }
    }

    @ViewBuilder
    private var overrideRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $overrideEnabled) {
                HStack(spacing: 4) {
                    Text("Customize prompt text")
                    InfoTip("Replace the prompt body for this Run only. Your saved prompt stays intact. Useful for A/B-testing wording variations without touching the saved definition.")
                }
            }
            .toggleStyle(.switch)
            .onChange(of: overrideEnabled) { _, enabled in
                if enabled { syncOverrideText() }
            }

            if overrideEnabled {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $overridePromptText)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 80, maxHeight: 200)
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                        )

                    if overridePromptText.isEmpty {
                        Text(Self.defaultOverridePlaceholder)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }

                HStack(spacing: 8) {
                    Button("Reset to saved text") {
                        syncOverrideText(force: true)
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(resolvedTestPrompt == nil)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Input + output

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Input")
                .font(.caption)
                .foregroundColor(.secondary)
            TextEditor(text: $inputText)
                .font(.system(size: 13))
                .frame(minHeight: 70, maxHeight: 140)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
                .overlay(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text(Self.defaultPlaceholder)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var runRow: some View {
        HStack(spacing: 8) {
            Button {
                runTest()
            } label: {
                HStack(spacing: 6) {
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                    }
                    Text(isRunning ? "Running…" : "Run enhancement")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(isRunning || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if !outputText.isEmpty || errorMessage != nil {
                Button("Clear") {
                    outputText = ""
                    errorMessage = nil
                    lastDuration = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer()

            if let duration = lastDuration {
                Text(String(format: "%.2fs", duration))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private var outputArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Output")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(outputText, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Copy output to clipboard")
            }
            ScrollView {
                Text(outputText)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(minHeight: 70, maxHeight: 160)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Runtime

    private func runTest() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        outputText = ""
        lastDuration = nil
        isRunning = true

        let override = makeOverridePrompt()

        Task {
            do {
                let (result, duration, _) = try await enhancementService.enhance(trimmed, overridePrompt: override)
                await MainActor.run {
                    outputText = result
                    lastDuration = duration
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRunning = false
                }
            }
        }
    }

    /// Builds the synthetic CustomPrompt for the sandbox run. Returns nil when
    /// the user kept the globally-active prompt AND did not enable text
    /// override, in which case `enhance` falls back to its normal resolution
    /// (activePrompt → Default → first).
    private func makeOverridePrompt() -> CustomPrompt? {
        guard let base = resolvedTestPrompt else { return nil }

        let needsPromptSwitch = base.id != enhancementService.activePrompt?.id
        if !overrideEnabled && !needsPromptSwitch {
            return nil
        }

        let body = overrideEnabled
            ? overridePromptText.trimmingCharacters(in: .whitespacesAndNewlines)
            : base.promptText

        let safeBody = body.isEmpty ? base.promptText : body

        return CustomPrompt(
            id: base.id,
            title: base.title,
            promptText: safeBody,
            isActive: base.isActive,
            icon: base.icon,
            description: base.description,
            isPredefined: false,
            triggerWords: base.triggerWords,
            useSystemInstructions: base.useSystemInstructions,
            vocabularyDomains: base.vocabularyDomains,
            category: base.category
        )
    }

    /// Initialises the local picker + override text from the globally active
    /// prompt the first time the disclosure opens. Subsequent re-opens keep
    /// whatever the user picked last.
    private func syncDefaults() {
        if testPromptId == nil {
            testPromptId = enhancementService.activePrompt?.id ?? availablePrompts.first?.id
        }
        if overridePromptText.isEmpty {
            syncOverrideText()
        }
    }

    /// Refreshes the override text with the currently-selected prompt's body.
    /// `force` ignores the "user already edited" heuristic so the Reset
    /// button can always restore the canonical text.
    private func syncOverrideText(force: Bool = false) {
        guard let base = resolvedTestPrompt else { return }
        if force {
            overridePromptText = base.promptText
            return
        }
        // Only auto-sync if the editor is empty or matches the previous base
        // — avoids stomping on edits the user has in progress when they
        // toggle the picker.
        let trimmed = overridePromptText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            overridePromptText = base.promptText
        }
    }
}

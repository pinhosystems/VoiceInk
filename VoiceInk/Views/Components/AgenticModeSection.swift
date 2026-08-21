import SwiftUI

/// Settings for Agentic Mode: the agent replaces the enhancement stage,
/// understanding intent and producing the final text. See AgenticProcessor.
struct AgenticModeSection: View {
    @AppStorage(AgenticSettings.enabledKey) private var isEnabled = false
    @AppStorage(AgenticSettings.routerModelKey) private var routerModel = ""
    @AppStorage(AgenticSettings.allowPromptKey) private var allowPrompt = true
    @AppStorage(AgenticSettings.allowProfileKey) private var allowProfile = true
    @AppStorage(AgenticSettings.allowOutputLanguageKey) private var allowOutputLanguage = true

    var body: some View {
        Section {
            Toggle(isOn: $isEnabled) {
                HStack(spacing: 4) {
                    Text("Enable Agentic Mode")
                    InfoTip("Replaces the enhancement stage with an agent that understands intent: plain dictation is cleaned per the active prompt's rules, and requests like \"escreve um email formal pedindo...\" produce the finished artifact directly. Sticky voice commands (\"a partir de agora modo código\") switch prompt, profile, or output language for the session. Requires Enhancement ON; falls back to classic enhancement on failure.")
                }
            }
            .toggleStyle(.switch)

            if isEnabled {
                TextField("Agent model", text: $routerModel, prompt: Text("Same as enhancement model"))
                    .textFieldStyle(.roundedBorder)

                Text("Runs on the current AI provider. The agent writes the final text, so pick a model you trust for writing; leave empty to reuse the enhancement model.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Sticky voice commands may change:")
                        .font(.system(size: 12, weight: .semibold))
                    Toggle("Prompt", isOn: $allowPrompt)
                    Toggle("Profile", isOn: $allowProfile)
                    Toggle("Output language", isOn: $allowOutputLanguage)
                }
                .toggleStyle(.checkbox)
            }
        } header: {
            Text("Agentic Mode")
        }
    }
}

import SwiftUI

/// Settings for the agentic router: natural-language meta-directives spoken
/// mid-dictation ("isso aqui é um email formal") reconfigure the pipeline.
/// See AgenticRouterService.
struct AgenticModeSection: View {
    @AppStorage(AgenticSettings.enabledKey) private var isEnabled = false
    @AppStorage(AgenticSettings.routerModelKey) private var routerModel = ""
    @AppStorage(AgenticSettings.allowPromptKey) private var allowPrompt = true
    @AppStorage(AgenticSettings.allowProfileKey) private var allowProfile = true
    @AppStorage(AgenticSettings.allowDeliveryKey) private var allowDelivery = true
    @AppStorage(AgenticSettings.allowAutosendKey) private var allowAutosend = true
    @AppStorage(AgenticSettings.allowOutputLanguageKey) private var allowOutputLanguage = true

    var body: some View {
        Section {
            Toggle(isOn: $isEnabled) {
                HStack(spacing: 4) {
                    Text("Enable Agentic Mode")
                    InfoTip("An LLM agent reads each dictation for spoken meta-instructions — \"isso aqui é um email formal\", \"only copy, don't paste\", \"a partir de agora modo código\" — applies them, and strips them from the text. When it finds none, the dictation behaves exactly as usual. Adds one small LLM call per dictation.")
                }
            }
            .toggleStyle(.switch)

            if isEnabled {
                TextField("Router model", text: $routerModel, prompt: Text("Same as enhancement model"))
                    .textFieldStyle(.roundedBorder)

                Text("Runs on the current AI provider. Pick a small, fast model here to keep the extra latency low; leave empty to reuse the enhancement model.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 6) {
                    Text("The agent may change:")
                        .font(.system(size: 12, weight: .semibold))
                    Toggle("Prompt", isOn: $allowPrompt)
                    Toggle("Profile (session-wide)", isOn: $allowProfile)
                    Toggle("Delivery (paste vs clipboard only)", isOn: $allowDelivery)
                    Toggle("Auto-send key", isOn: $allowAutosend)
                    Toggle("Output language", isOn: $allowOutputLanguage)
                }
                .toggleStyle(.checkbox)
            }
        } header: {
            Text("Agentic Mode")
        }
    }
}

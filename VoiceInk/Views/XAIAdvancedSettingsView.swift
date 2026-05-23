import SwiftUI

/// xAI-specific STT tuning controls. Persisted via `XAISettings` and
/// consumed by `XAIProvider` (REST) and `XAIStreamingProvider` (WebSocket).
/// The controls only affect xAI runs; other providers ignore them.
///
/// Scope deliberately narrow:
/// - `endpointing` is the streaming bug-fix knob (previously hard-coded
///   800ms, which clipped sentences at thinking pauses).
/// - `format` toggles Inverse Text Normalization for REST.
///
/// `filler_words`, `diarize`, and `multichannel` from the xAI API are not
/// exposed here — see `XAISettings` for the reasoning.
///
/// Rendered as direct Form rows so the grouped Form layout (sidebar +
/// trailing controls) handles alignment.
struct XAIAdvancedSettingsView: View {

    @AppStorage(XAISettings.Key.endpointingMs) private var endpointingMs: Int = XAISettings.defaultEndpointingMs
    @AppStorage(XAISettings.Key.format) private var format: Bool = XAISettings.defaultFormat

    private static let endpointingOptions: [Int] = [0, 250, 500, 800, 1000, 1500, 2000, 2500, 3000, 4000, 5000]

    var body: some View {
        Group {
            Picker(selection: $endpointingMs) {
                ForEach(Self.endpointingOptions, id: \.self) { ms in
                    Text("\(ms) ms").tag(ms)
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Streaming endpointing")
                    InfoTip("How long the xAI streaming engine waits during silence before finalizing an utterance. Lower = snappier commits but cuts during thinking pauses. Higher = more natural pauses but slower commits. Default 1500ms.")
                }
            }
            .pickerStyle(.menu)

            Toggle(isOn: $format) {
                HStack(spacing: 4) {
                    Text("Apply text formatting (REST)")
                    InfoTip("Inverse Text Normalization: numbers, dates, and other entities are formatted. Only applies to batch (REST) requests, and only when a specific language is selected.")
                }
            }
            .toggleStyle(.switch)
        }
    }
}

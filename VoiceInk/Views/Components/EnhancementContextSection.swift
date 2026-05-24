import SwiftUI

/// The three Context source rows (selected text, clipboard, screen) that feed
/// the LLM enhancement prompt. Extracted so the Enhancement screen and the
/// legacy settings panel can mount the same controls from a single source of
/// truth.
struct EnhancementContextSection: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService

    var body: some View {
        Section {
            contextRow(
                title: "Selected Text Context",
                info: "Attach the text currently selected in the focused app. Disable this in terminals or editors where selection is unreliable and tends to leak unrelated content into the prompt.",
                isOn: $enhancementService.useSelectedTextContext,
                maxChars: $enhancementService.selectedTextContextMaxChars
            )

            contextRow(
                title: "Clipboard Context",
                info: "Attach the current clipboard contents to give the model recent context.",
                isOn: $enhancementService.useClipboardContext,
                maxChars: $enhancementService.clipboardContextMaxChars
            )

            contextRow(
                title: "Screen Context",
                info: "Attach OCR-extracted text from the focused window to give the model situational context.",
                isOn: $enhancementService.useScreenCaptureContext,
                maxChars: $enhancementService.screenCaptureContextMaxChars
            )
        } header: {
            HStack(spacing: 4) {
                Text("Context")
                InfoTip("Extra information attached to the LLM prompt. Each source has its own toggle and a per-source character cap so a noisy clipboard or screen capture cannot swamp the model input.")
            }
        }
    }

    /// A toggle plus an inline character-limit stepper that appears only when
    /// the toggle is on.
    @ViewBuilder
    private func contextRow(
        title: String,
        info: String,
        isOn: Binding<Bool>,
        maxChars: Binding<Int>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: isOn) {
                HStack(spacing: 4) {
                    Text(title)
                    InfoTip(info)
                }
            }
            .toggleStyle(.switch)

            if isOn.wrappedValue {
                HStack(spacing: 8) {
                    Text("Max characters")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(maxChars.wrappedValue)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .frame(minWidth: 56, alignment: .trailing)
                    Stepper("Max characters", value: maxChars, in: 500...32000, step: 500)
                        .labelsHidden()
                }
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isOn.wrappedValue)
    }
}

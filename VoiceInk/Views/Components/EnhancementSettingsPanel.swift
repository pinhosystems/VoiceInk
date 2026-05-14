import SwiftUI

struct EnhancementSettingsPanel: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @AppStorage("SkipShortEnhancement") private var isSkipShortEnhancementEnabled = true
    @AppStorage("ShortEnhancementWordThreshold") private var shortEnhancementWordThreshold = 3
    @AppStorage("EnhancementTimeoutSeconds") private var enhancementTimeoutSeconds = 7
    @AppStorage("EnhancementRetryOnTimeout") private var retryOnTimeout = true
    @State private var isShortEnhancementExpanded = false
    @State private var isHandlingToggleChange = false

    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("Enhancement Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: onDismiss) {
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
            Form {
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
                    Text("Context")
                }

                Section {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Toggle(isOn: Binding(
                                get: { isSkipShortEnhancementEnabled },
                                set: { newValue in
                                    isHandlingToggleChange = true
                                    isSkipShortEnhancementEnabled = newValue
                                    if newValue {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isShortEnhancementExpanded = true
                                        }
                                    } else {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            isShortEnhancementExpanded = false
                                        }
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        isHandlingToggleChange = false
                                    }
                                }
                            )) {
                                HStack(spacing: 4) {
                                    Text("Skip short transcriptions")
                                    InfoTip("Automatically skip AI enhancement when the transcription has very few words. Short phrases like \"yes\", \"thank you\", or quick commands don't benefit from enhancement.")
                                }
                            }
                            .toggleStyle(.switch)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                                .rotationEffect(.degrees(isSkipShortEnhancementEnabled && isShortEnhancementExpanded ? 90 : 0))
                                .opacity(isSkipShortEnhancementEnabled ? 1 : 0.4)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !isHandlingToggleChange else { return }
                            if isSkipShortEnhancementEnabled {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isShortEnhancementExpanded.toggle()
                                }
                            }
                        }

                        if isSkipShortEnhancementEnabled && isShortEnhancementExpanded {
                            Picker("Minimum words", selection: $shortEnhancementWordThreshold) {
                                ForEach(1...15, id: \.self) { count in
                                    Text("\(count) \(count == 1 ? "word" : "words")").tag(count)
                                }
                            }
                            .padding(.top, 12)
                            .padding(.leading, 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.2), value: isShortEnhancementExpanded)
                }

                Section {
                    Picker("Timeout duration", selection: $enhancementTimeoutSeconds) {
                        ForEach([3, 5, 7, 10, 15, 20, 30, 40, 50, 60], id: \.self) { seconds in
                            Text("\(seconds) seconds").tag(seconds)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("On timeout", selection: $retryOnTimeout) {
                        Text("Fail immediately").tag(false)
                        Text("Retry").tag(true)
                    }
                    .pickerStyle(.menu)
                } header: {
                    HStack(spacing: 4) {
                        Text("Request Timeout")
                        InfoTip("Set how long to wait for the AI provider to respond. If no response is received within this duration, you can either fail immediately and paste the original transcription, or retry the request (up to 3 attempts).")
                    }
                }

                Section {
                    EnhancementShortcutsView()
                } header: {
                    Text("Shortcuts")
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
        }
    }

    /// A toggle plus an inline character-limit stepper that appears only when
    /// the toggle is on. Keeps the three context sources visually consistent
    /// and surfaces the cap directly next to the switch that turns it on, so
    /// the user always knows exactly how much of each source can flow into the
    /// model prompt.
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

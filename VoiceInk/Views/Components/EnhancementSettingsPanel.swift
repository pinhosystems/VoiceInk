import SwiftUI

struct EnhancementSettingsPanel: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @AppStorage("SkipShortEnhancement") private var isSkipShortEnhancementEnabled = true
    @AppStorage("ShortEnhancementWordThreshold") private var shortEnhancementWordThreshold = 3
    @AppStorage("EnhancementTimeoutSeconds") private var enhancementTimeoutSeconds = 7
    @AppStorage("EnhancementRetryOnTimeout") private var retryOnTimeout = true
    @AppStorage("SelectedLanguage") private var selectedLanguage = "en"
    @AppStorage(LocalePackRegistry.normalizationEnabledKey) private var localeNormalizationEnabled = true
    @AppStorage(LocalePackRegistry.outputLanguageKey)
    private var llmOutputLanguage = LocalePackRegistry.outputLanguageMatchSentinel
    @State private var isShortEnhancementExpanded = false
    @State private var isHandlingToggleChange = false

    var onDismiss: () -> Void

    /// Picker entries for the LLM output-language override. The sentinel
    /// `"match"` keeps legacy behavior; the rest are explicit BCP-47 codes
    /// for the languages we most often translate into. Adding more options
    /// is a one-line edit.
    private static let outputLanguageOptions: [(code: String, label: String)] = [
        (LocalePackRegistry.outputLanguageMatchSentinel, "Match transcription (default)"),
        ("en", "English"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("pt-PT", "Portuguese (Portugal)"),
        ("es", "Spanish"),
        ("fr", "French"),
        ("de", "German"),
        ("it", "Italian"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("zh", "Chinese")
    ]

    private var sttPack: LocalePack? {
        LocalePackRegistry.pack(for: selectedLanguage)
    }

    private var hasNormalizationContent: Bool {
        guard let pack = sttPack else { return false }
        return !pack.normalizerRules.isEmpty || pack.customNormalize != nil
    }

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
                    Picker(selection: $llmOutputLanguage) {
                        ForEach(Self.outputLanguageOptions, id: \.code) { option in
                            Text(option.label).tag(option.code)
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text("LLM output language")
                            InfoTip("Forces the LLM enhancement step to respond in the chosen language regardless of what the transcription language is. \"Match transcription\" keeps the legacy behavior — same language in and out. Pick any other value to translate (e.g. dictate in Portuguese, get an English email).")
                        }
                    }
                    .pickerStyle(.menu)

                    Text("Decoupled from the transcription provider. Picking any value other than \"Match transcription\" turns the LLM step into a translate-and-clean pass.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    let normLabel = sttPack.map { "\($0.displayName) normalization" } ?? "Locale text normalization"
                    Toggle(isOn: $localeNormalizationEnabled) {
                        HStack(spacing: 4) {
                            Text(normLabel)
                            InfoTip(hasNormalizationContent
                                    ? "Post-transcription text formatting: numbers, dates, currency, and identifiers (CPF, CNPJ, CEP, R$, 14h30) are reshaped before the LLM sees the text. Does NOT change the transcription language — pick that under AI Models."
                                    : "The selected transcription language has no curated input transforms. This toggle is inert until a pack ships them.")
                        }
                    }
                    .toggleStyle(.switch)
                    .disabled(!hasNormalizationContent)

                    Text(hasNormalizationContent
                         ? "Post-transcription text formatting. Does not change the transcription language."
                         : "No curated formatting rules ship for the current transcription language.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } header: {
                    HStack(spacing: 4) {
                        Text("Locale")
                        InfoTip("LLM output language picks the response language. The normalization toggle applies locale-specific text shaping (e.g. CPF/R$/dd-mm-aaaa for pt-BR) BEFORE the LLM sees the transcript.")
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

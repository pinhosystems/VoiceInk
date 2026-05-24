import SwiftUI

/// The Locale & Formatting block: LLM output-language picker, the Text
/// normalization toggle, and the per-pack examples disclosure. Extracted from
/// the settings panel so the main Enhancement screen can host it directly
/// without trapping the controls behind a gear icon.
struct EnhancementLocaleSection: View {
    @AppStorage("SelectedLanguage") private var selectedLanguage = "en"
    @AppStorage(LocalePackRegistry.normalizationEnabledKey) private var localeNormalizationEnabled = true
    @AppStorage(LocalePackRegistry.outputLanguageKey)
    private var llmOutputLanguage = LocalePackRegistry.outputLanguageMatchSentinel

    @State private var isNormalizationExamplesExpanded = false

    /// Picker entries for the LLM output-language override. The sentinel
    /// `"match"` keeps legacy behavior; the rest are explicit BCP-47 codes
    /// for the languages we most often translate into.
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

    private var examplesPack: LocalePack? {
        let effective = LocalePackRegistry.outputLanguageCode(sttCode: selectedLanguage)
        return LocalePackRegistry.pack(for: effective)
    }

    private var hasNormalizationContent: Bool {
        guard let pack = sttPack else { return false }
        return !pack.normalizerRules.isEmpty || pack.customNormalize != nil
    }

    private var selectedLanguageDisplayName: String {
        let raw = selectedLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw.lowercased() == "auto" { return "the auto-detected language" }
        let locale = Locale(identifier: "en")
        return locale.localizedString(forIdentifier: raw)
            ?? locale.localizedString(forLanguageCode: raw)
            ?? raw
    }

    private var normalizationCaption: String {
        if let pack = sttPack, hasNormalizationContent {
            return "Active for \(pack.displayName) (\(pack.bcp47 ?? pack.primarySubtag)). Other languages are pass-through."
        }
        return "No curated formatting rules ship for \(selectedLanguageDisplayName). Switch to a supported locale (e.g. Brazilian Portuguese) to see this toggle take effect."
    }

    private var examplesDisclosureLabel: String {
        if let pack = examplesPack {
            return "See examples for \(pack.displayName)"
        }
        return "See examples"
    }

    private var noExamplesMessage: String {
        if let pack = examplesPack {
            return "No formatting examples shipped for \(pack.displayName) yet. The LLM will still apply the locale conventions described above; this disclosure shows samples once they land."
        }
        return "No formatting examples shipped for the selected language yet."
    }

    var body: some View {
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

            Toggle(isOn: $localeNormalizationEnabled) {
                HStack(spacing: 4) {
                    Text("Text normalization")
                    InfoTip("Locale-aware post-transcription formatting: numbers, dates, currency, and identifiers are reshaped before the LLM sees the text. The set of transforms is chosen automatically from the current transcription language — no rules ship for languages without a curated pack. Does NOT change the transcription language itself.")
                }
            }
            .toggleStyle(.switch)
            .disabled(!hasNormalizationContent)

            Text(normalizationCaption)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DisclosureGroup(examplesDisclosureLabel, isExpanded: $isNormalizationExamplesExpanded) {
                if let pack = examplesPack, !pack.normalizationExamples.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(pack.normalizationExamples, id: \.before) { example in
                            HStack(alignment: .top, spacing: 6) {
                                Text(example.before)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text(example.after)
                                    .font(.system(size: 12, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.top, 4)
                } else {
                    Text(noExamplesMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
            .font(.caption)
        } header: {
            HStack(spacing: 4) {
                Text("Locale & Formatting")
                InfoTip("LLM output language picks the response language. Text normalization applies locale-specific text shaping (driven by the current transcription language) BEFORE the LLM sees the transcript.")
            }
        }
    }
}

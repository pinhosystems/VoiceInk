import Foundation

/// Synthesised fallback pack for any non-English BCP-47 locale that does not
/// match a curated entry in `LocalePackRegistry`. Ships output-only content
/// derived from the primary subtag: empty input transforms, a single-sentence
/// LLM format-rules block, and a stub Whisper seed. The displayName is
/// resolved via Apple's `Locale` API so the LLM and UI both refer to the
/// language by its canonical English name.
///
/// See Section 7.4 of `docs/MULTILINGUAL_PLAN.md` for the "generic packs are
/// output-only by design" rationale.
struct GenericLocalePack: LocalePack {
    let primarySubtag: String
    let displayName: String

    init(primarySubtag: String) {
        let lowered = primarySubtag.lowercased()
        self.primarySubtag = lowered
        self.displayName = Locale(identifier: "en")
            .localizedString(forLanguageCode: lowered)?
            .capitalized
            ?? lowered.uppercased()
    }

    let normalizerRules: [NormalizerRule] = []
    let wordReplacements: [(original: String, replacement: String)] = []
    let vocabularyTerms: [String] = []
    let fillerWords: [String] = []

    var whisperPromptSeeds: [String: String] {
        ["default": "Transcription in \(displayName)."]
    }

    var aiPromptFormatRules: String {
        "Use \(displayName) conventions for numbers, dates, currency, and punctuation."
    }
}

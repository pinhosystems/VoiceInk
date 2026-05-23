import Foundation

/// A bundle of locale-specific behavior the transcription + LLM pipeline can
/// look up at runtime. Curated packs ship hand-tuned content for a language;
/// the registry synthesises a generic pack for every other non-English locale.
///
/// One pack covers a primary BCP-47 subtag (e.g. "pt" covers both pt-BR and
/// pt-PT). Region-specific packs are a future extension — see Section 7.5 of
/// `docs/MULTILINGUAL_PLAN.md`.
protocol LocalePack {
    /// BCP-47 primary subtag this pack matches (e.g. "pt", "es"). Lowercase.
    var primarySubtag: String { get }

    /// Human-readable label shown in settings copy ("Brazilian Portuguese",
    /// "Spanish (generic)"). English string by convention; the UI does not
    /// translate it.
    var displayName: String { get }

    /// Ordered regex rules applied to STT output before LLM enhancement. Order
    /// matters: earlier rules may produce strings later rules then match.
    var normalizerRules: [NormalizerRule] { get }

    /// Suggested abbreviation expansions for this locale. Seeded into the
    /// user's `WordReplacement` rows when they click the "Add … abbreviations"
    /// button. Idempotent re-seeding is enforced by the consumer.
    var wordReplacements: [(original: String, replacement: String)] { get }

    /// High-frequency words with non-trivial spelling that benefit from
    /// vocabulary biasing on cloud STT engines (Deepgram `keyterm`, ElevenLabs
    /// `customVocabulary`, etc.) and from prompt seeding for local Whisper.
    var vocabularyTerms: [String] { get }

    /// Locale-typical filler words removed by `FillerWordManager` when the
    /// active language matches this pack. Unioned with the user's filler list.
    var fillerWords: [String] { get }

    /// Domain-keyed Whisper prompt seeds. The "default" key is the unmarked
    /// seed used when no specialised domain is requested. Additional keys
    /// (e.g. "technical") match `WhisperPromptDomain` raw values.
    var whisperPromptSeeds: [String: String] { get }

    /// Body of the `<LOCALE_RULES>` block injected into the LLM system
    /// message. Tells the model how to format numbers, dates, currency, and
    /// punctuation for this locale. Generic packs ship a single sentence;
    /// curated packs ship the full conventions block.
    var aiPromptFormatRules: String { get }
}

/// A single regex-based normalization step contributed by a `LocalePack`. The
/// description is logged in debug builds whenever the rule fires, and surfaces
/// in the troubleshooting panel as the human-readable label for the change.
struct NormalizerRule {
    let pattern: NSRegularExpression
    let replacement: String
    let description: String

    init(pattern: NSRegularExpression, replacement: String, description: String) {
        self.pattern = pattern
        self.replacement = replacement
        self.description = description
    }

    /// Convenience initialiser for the common case where the pattern is built
    /// from a string literal at pack construction time. Crashes with a clear
    /// message at startup if the regex fails to compile — a pack ships broken
    /// patterns at most once.
    init(
        pattern source: String,
        options: NSRegularExpression.Options = [],
        replacement: String,
        description: String
    ) {
        do {
            self.pattern = try NSRegularExpression(pattern: source, options: options)
        } catch {
            fatalError("LocalePack: invalid regex '\(source)' (\(description)): \(error)")
        }
        self.replacement = replacement
        self.description = description
    }
}

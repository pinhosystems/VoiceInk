import Foundation

/// A coarse-grained category of vocabulary terms that a prompt template can
/// pull in at transcription time. Each domain maps to a concrete source —
/// either the user's manually-curated `VocabularyWord` rows or one of the
/// canonical built-in lists (`BrazilianVocabularyTemplate`,
/// `TechnicalVocabularyTemplate`).
///
/// `VocabularyResolver` aggregates the terms of every domain attached to the
/// active `CustomPrompt`, deduplicates them, and forwards the result both to
/// the STT layer (`keyterm` on xAI, `customVocabulary` on Deepgram/Soniox/etc.)
/// and to the LLM enhancement layer (`CustomVocabularyService`).
///
/// `userVocabulary` is treated as always-on: even prompts that don't list it
/// explicitly still get the user's manual entries. The domain list on each
/// prompt is therefore "what to add on top of the user's own vocabulary".
enum VocabularyDomain: String, Codable, CaseIterable, Sendable {
    case userVocabulary
    case technical
    case brazilian
}

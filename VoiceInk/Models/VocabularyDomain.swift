import Foundation

/// A coarse-grained category of vocabulary terms that a prompt template can
/// pull in at transcription time. Each domain maps to a concrete source —
/// either the user's manually-curated `VocabularyWord` rows, the canonical
/// English technical list (`TechnicalVocabularyTemplate`), or a locale-bound
/// curated list resolved through `LocalePackRegistry`.
///
/// `VocabularyResolver` aggregates the terms of every domain attached to the
/// active `CustomPrompt`, deduplicates them, and forwards the result both to
/// the STT layer (`keyterm` on xAI, `customVocabulary` on Deepgram/Soniox/etc.)
/// and to the LLM enhancement layer (`CustomVocabularyService`).
///
/// `userVocabulary` is treated as always-on: even prompts that don't list it
/// explicitly still get the user's manual entries. The domain list on each
/// prompt is therefore "what to add on top of the user's own vocabulary".
///
/// **Codable wire format**: each case encodes as a single string token. Static
/// cases use their plain identifier (`"userVocabulary"`, `"technical"`); the
/// locale case uses the prefix form `"locale:<bcp47>"` (e.g. `"locale:pt-BR"`).
/// The legacy `"brazilian"` token from earlier builds decodes to
/// `.locale("pt-BR")` for forward compatibility — existing user prompts
/// continue to load without manual intervention.
enum VocabularyDomain: Codable, Hashable, Sendable {
    case userVocabulary
    case technical
    case locale(String) // BCP-47 code, e.g. "pt-BR"

    /// Locale-agnostic cases, in priority order. Locale-bound cases come from
    /// the active `CustomPrompt.vocabularyDomains` at runtime.
    static let staticCases: [VocabularyDomain] = [.userVocabulary, .technical]

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        switch raw {
        case "userVocabulary": self = .userVocabulary
        case "technical":      self = .technical
        case "brazilian":      self = .locale("pt-BR") // legacy migration
        default:
            if raw.hasPrefix("locale:") {
                let code = String(raw.dropFirst("locale:".count))
                guard !code.isEmpty else {
                    throw DecodingError.dataCorruptedError(
                        in: container,
                        debugDescription: "VocabularyDomain locale tag missing BCP-47 code"
                    )
                }
                self = .locale(code)
            } else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown VocabularyDomain tag '\(raw)'"
                )
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .userVocabulary:    try container.encode("userVocabulary")
        case .technical:         try container.encode("technical")
        case .locale(let code):  try container.encode("locale:\(code)")
        }
    }
}

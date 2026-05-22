import Foundation
import SwiftData

/// Aggregates vocabulary terms across every domain attached to the active
/// `CustomPrompt`, applies the STT-side limits (xAI documents `keyterm` at max
/// 100 entries, each up to 50 characters), and returns a single deduplicated
/// list. The same list is used by:
///
/// - STT providers that accept a `keyterm`/`customVocabulary` bias (xAI,
///   Deepgram, Soniox, AssemblyAI, Speechmatics) — via
///   `CloudTranscriptionService.getCustomDictionaryTerms()`
/// - The LLM enhancement step — via `CustomVocabularyService` (so the LLM and
///   the STT see exactly the same vocabulary).
///
/// Priority order when truncating to 100:
///   1. `userVocabulary` — the user's manual entries always win
///   2. `technical`     — canonical EN tech terms
///   3. `brazilian`     — Brazilian institutions/orgs/cities
///
/// Within each domain entries keep their source order (alphabetical for user
/// vocab via the fetch descriptor, declared order for the built-in lists).
enum VocabularyResolver {

    /// Hard cap on number of terms forwarded to STT providers. xAI documents
    /// the limit; other providers tolerate longer lists silently. Truncating
    /// universally keeps behavior consistent across providers.
    static let maxTerms = 100

    /// Per-term character cap. xAI rejects terms longer than 50 chars. Terms
    /// over the limit are dropped rather than truncated mid-word — a partial
    /// term would not help phonetic bias and might collide with another entry.
    static let maxTermLength = 50

    /// Resolves the terms for the given active prompt. If `activePrompt` is
    /// nil (e.g. enhancement disabled or no prompt selected), behavior falls
    /// back to user vocabulary only — same as the legacy "always dump every
    /// VocabularyWord row" path that existed before domain tagging.
    static func resolve(for activePrompt: CustomPrompt?, context: ModelContext) -> [String] {
        let domains = activePrompt?.vocabularyDomains ?? [.userVocabulary]
        return resolve(domains: domains, context: context)
    }

    /// Reads the active prompt out of UserDefaults directly. Used by sites
    /// that don't have a reference to `AIEnhancementService` (e.g.
    /// `CloudTranscriptionService` which lives below the enhancement layer).
    static func resolveFromUserDefaults(context: ModelContext) -> [String] {
        return resolve(for: activePromptFromUserDefaults(), context: context)
    }

    private static func activePromptFromUserDefaults() -> CustomPrompt? {
        guard
            let idString = UserDefaults.standard.string(forKey: "selectedPromptId"),
            let id = UUID(uuidString: idString),
            let data = UserDefaults.standard.data(forKey: "customPrompts"),
            let prompts = try? JSONDecoder().decode([CustomPrompt].self, from: data)
        else { return nil }
        return prompts.first(where: { $0.id == id })
    }

    static func resolve(domains: [VocabularyDomain], context: ModelContext) -> [String] {
        // Deduplicate as we go, case-insensitive. Keep the first spelling we
        // see (so the user's canonical capitalization wins over a built-in).
        var seen = Set<String>()
        var ordered: [String] = []

        // Stable priority: user > technical > brazilian.
        let priority: [VocabularyDomain] = [.userVocabulary, .technical, .brazilian]
        let active = priority.filter { domains.contains($0) }

        for domain in active {
            let words = words(for: domain, context: context)
            for word in words {
                let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed.count <= maxTermLength else { continue }
                let key = trimmed.lowercased()
                if seen.insert(key).inserted {
                    ordered.append(trimmed)
                    if ordered.count >= maxTerms { return ordered }
                }
            }
        }

        return ordered
    }

    private static func words(for domain: VocabularyDomain, context: ModelContext) -> [String] {
        switch domain {
        case .userVocabulary:
            let descriptor = FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\.word)])
            return (try? context.fetch(descriptor).map(\.word)) ?? []
        case .technical:
            return TechnicalVocabularyTemplate.canonicalWords
        case .brazilian:
            return BrazilianVocabularyTemplate.canonicalWords
        }
    }
}

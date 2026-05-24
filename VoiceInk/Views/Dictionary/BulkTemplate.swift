import Foundation

/// Locale-keyed bulk-insert template surfaced by the Dictionary screen.
///
/// A template bundles a curated vocabulary list and a curated word-replacement
/// list (either side may be empty) together with a single user-facing
/// `displayName`. Locale-bound templates come from the curated `LocalePack`
/// registry — extending the supported locales is therefore a matter of adding
/// a new pack file with content, no extra wiring required.
///
/// Standalone (non-locale) templates live alongside the locale-keyed entries
/// and are namespaced by id (e.g. `english-technical`) so the picker keeps a
/// single, flat structure.
struct BulkTemplate: Identifiable, Hashable {
    let id: String
    let displayName: String
    let vocabularyTerms: [String]
    let wordReplacements: [(original: String, replacement: String)]

    static func == (lhs: BulkTemplate, rhs: BulkTemplate) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

/// Enumerates every `BulkTemplate` that ships with the binary. Order matters
/// only for the picker — curated locale packs first (alphabetical by display
/// name), then standalone templates such as `english-technical`.
enum BulkTemplateRegistry {

    static var all: [BulkTemplate] {
        let localeTemplates = LocalePackRegistry.curatedPacks
            .filter { !$0.vocabularyTerms.isEmpty || !$0.wordReplacements.isEmpty }
            .map { pack in
                BulkTemplate(
                    id: "locale:\(pack.bcp47 ?? pack.primarySubtag)",
                    displayName: pack.displayName,
                    vocabularyTerms: pack.vocabularyTerms,
                    wordReplacements: pack.wordReplacements
                )
            }
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }

        let standaloneTemplates: [BulkTemplate] = [
            BulkTemplate(
                id: "english-technical",
                displayName: "English — Technical",
                vocabularyTerms: TechnicalVocabularyTemplate.canonicalWords,
                wordReplacements: []
            )
        ]

        return localeTemplates + standaloneTemplates
    }

    /// Templates that ship at least one vocabulary term. Used by the
    /// vocabulary-bulk-add flow to avoid offering empty templates.
    static var templatesWithVocabulary: [BulkTemplate] {
        all.filter { !$0.vocabularyTerms.isEmpty }
    }

    /// Templates that ship at least one word replacement. Used by the
    /// abbreviations-bulk-add flow.
    static var templatesWithAbbreviations: [BulkTemplate] {
        all.filter { !$0.wordReplacements.isEmpty }
    }
}

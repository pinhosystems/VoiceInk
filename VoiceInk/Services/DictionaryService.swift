import Foundation
import OSLog
import SwiftData

enum DictionaryService {

    private static let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "DictionaryService")


    // MARK: - Vocabulary

    /// Adds one or more comma-separated words to vocabulary.
    /// Returns an error message string if something went wrong, nil on success.
    @discardableResult
    static func addVocabularyWords(
        _ input: String,
        existing: [VocabularyWord],
        context: ModelContext
    ) -> String? {
        let parts = input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return nil }

        if parts.count == 1, let word = parts.first {
            if existing.contains(where: { $0.word.lowercased() == word.lowercased() }) {
                return "'\(word)' is already in the vocabulary"
            }
            return insertVocabularyWord(word, context: context)
        }

        var addedWords = Set(existing.map { $0.word.lowercased() })
        var errors = [String]()
        for word in parts {
            let lower = word.lowercased()
            if !addedWords.contains(lower) {
                if let error = insertVocabularyWord(word, context: context) {
                    errors.append(error)
                }
                addedWords.insert(lower)
            }
        }
        return errors.isEmpty ? nil : errors.joined(separator: "; ")
    }

    @discardableResult
    private static func insertVocabularyWord(_ word: String, context: ModelContext) -> String? {
        let entry = VocabularyWord(word: word)
        context.insert(entry)
        do {
            try context.save()
            return nil
        } catch {
            context.delete(entry)
            return "Failed to add '\(word)': \(error.localizedDescription)"
        }
    }

    // MARK: - Word Replacement

    /// Adds a word replacement entry (original may be comma-separated).
    /// Returns an error message string if something went wrong, nil on success.
    @discardableResult
    static func addWordReplacement(
        original: String,
        replacement: String,
        existing: [WordReplacement],
        context: ModelContext
    ) -> String? {
        let tokens = original
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty, !replacement.isEmpty else { return nil }

        for existingEntry in existing {
            let existingTokens = existingEntry.originalText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }

            for token in tokens {
                if existingTokens.contains(token.lowercased()) {
                    return "'\(token)' already exists in word replacements"
                }
            }
        }

        let entry = WordReplacement(originalText: original, replacementText: replacement)
        context.insert(entry)
        do {
            try context.save()
            return nil
        } catch {
            context.delete(entry)
            return "Failed to add replacement: \(error.localizedDescription)"
        }
    }

    // MARK: - Bulk locale-pack templates

    struct BulkInsertResult {
        let added: Int
        let skipped: Int
        let errors: [String]
    }

    /// Inserts every entry from the given pack's `wordReplacements` that does
    /// not already exist (by case-insensitive match on any trigger token
    /// inside `originalText`). Idempotent — re-running over the same data
    /// produces 0 added. Returns a summary so the UI can render "Added X,
    /// skipped Y" without each row triggering an alert.
    @discardableResult
    static func addPackAbbreviations(
        pack: LocalePack,
        existing: [WordReplacement],
        context: ModelContext
    ) -> BulkInsertResult {
        var existingTokens = Set<String>()
        for entry in existing {
            for token in entry.originalText.split(separator: ",") {
                let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !trimmed.isEmpty { existingTokens.insert(trimmed) }
            }
        }

        var skipped = 0
        var errors: [String] = []
        var insertedEntries: [WordReplacement] = []

        for (original, replacement) in pack.wordReplacements {
            let tokens = original
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }

            // Skip if ANY token already exists; we don't want to duplicate triggers
            // because WordReplacementService applies the first match wins.
            if tokens.contains(where: { existingTokens.contains($0) }) {
                skipped += 1
                continue
            }

            let entry = WordReplacement(originalText: original, replacementText: replacement)
            context.insert(entry)
            insertedEntries.append(entry)
            for token in tokens { existingTokens.insert(token) }
        }

        var added = insertedEntries.count
        if !insertedEntries.isEmpty {
            do {
                try context.save()
            } catch {
                for entry in insertedEntries { context.delete(entry) }
                errors.append("Failed to save \(pack.displayName) abbreviations: \(error.localizedDescription)")
                added = 0
            }
        }

        return BulkInsertResult(added: added, skipped: skipped, errors: errors)
    }

    /// Inserts every entry from `TechnicalVocabularyTemplate.canonicalWords` that
    /// does not already exist (case-insensitive). Idempotent. Returns a summary
    /// for the UI. Any prompt with `.technical` in its `vocabularyDomains` then
    /// surfaces these terms through `VocabularyResolver`.
    @discardableResult
    static func addTechnicalVocabulary(
        existing: [VocabularyWord],
        context: ModelContext
    ) -> BulkInsertResult {
        return addVocabularyBatch(
            words: TechnicalVocabularyTemplate.canonicalWords,
            existing: existing,
            context: context,
            errorLabel: "technical vocabulary"
        )
    }

    /// Inserts every entry from the given pack's `vocabularyTerms` that does
    /// not already exist (case-insensitive). Idempotent. Returns a summary
    /// for the UI.
    @discardableResult
    static func addPackVocabulary(
        pack: LocalePack,
        existing: [VocabularyWord],
        context: ModelContext
    ) -> BulkInsertResult {
        return addVocabularyBatch(
            words: pack.vocabularyTerms,
            existing: existing,
            context: context,
            errorLabel: "\(pack.displayName) vocabulary"
        )
    }

    /// Shared batch-insert path for vocabulary templates. Dedupes against the
    /// existing rows AND against in-flight inserts in the same batch (the
    /// source list may contain repeated entries). Single save at the end keeps
    /// the operation atomic — partial failure rolls back the whole batch.
    private static func addVocabularyBatch(
        words: [String],
        existing: [VocabularyWord],
        context: ModelContext,
        errorLabel: String
    ) -> BulkInsertResult {
        var existingWords = Set(existing.map { $0.word.lowercased() })
        var skipped = 0
        var errors: [String] = []
        var insertedEntries: [VocabularyWord] = []

        for word in words {
            let lower = word.lowercased()
            if existingWords.contains(lower) {
                skipped += 1
                continue
            }
            let entry = VocabularyWord(word: word)
            context.insert(entry)
            insertedEntries.append(entry)
            existingWords.insert(lower)
        }

        var added = insertedEntries.count
        if !insertedEntries.isEmpty {
            do {
                try context.save()
            } catch {
                for entry in insertedEntries { context.delete(entry) }
                errors.append("Failed to save \(errorLabel): \(error.localizedDescription)")
                added = 0
            }
        }

        return BulkInsertResult(added: added, skipped: skipped, errors: errors)
    }

    // MARK: - Bulk delete

    /// Removes every vocabulary word. Returns the number deleted, or nil if the
    /// save failed (deletes are rolled back via `context.rollback()`).
    @discardableResult
    static func clearAllVocabulary(context: ModelContext) -> Int? {
        let descriptor = FetchDescriptor<VocabularyWord>()
        guard let entries = try? context.fetch(descriptor) else { return 0 }
        guard !entries.isEmpty else { return 0 }
        for entry in entries { context.delete(entry) }
        do {
            try context.save()
            return entries.count
        } catch {
            context.rollback()
            return nil
        }
    }

    /// Removes every word replacement entry. Returns the number deleted, or nil
    /// if the save failed (deletes are rolled back via `context.rollback()`).
    @discardableResult
    static func clearAllWordReplacements(context: ModelContext) -> Int? {
        let descriptor = FetchDescriptor<WordReplacement>()
        guard let entries = try? context.fetch(descriptor) else { return 0 }
        guard !entries.isEmpty else { return 0 }
        for entry in entries { context.delete(entry) }
        do {
            try context.save()
            return entries.count
        } catch {
            context.rollback()
            return nil
        }
    }

    // MARK: - Dedupe migration

    /// One-shot migration that removes duplicate vocabulary words and overlapping
    /// word-replacement entries persisted by earlier builds (the legacy bulk
    /// inserter did not dedupe against in-flight inserts, so the same template
    /// list could create the same row twice). Gated by a versioned UserDefaults
    /// flag so it runs at most once per device. Re-runnable safely: if save
    /// fails the flag stays unset and the next launch retries.
    @MainActor
    static func runDedupeMigrationIfNeeded(context: ModelContext) {
        let key = "DictionaryDedupeMigrationCompleted_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }

        let vocabRemoved = dedupeVocabulary(context: context)
        let replacementRemoved = dedupeWordReplacements(context: context)

        guard vocabRemoved > 0 || replacementRemoved > 0 else {
            UserDefaults.standard.set(true, forKey: key)
            return
        }

        do {
            try context.save()
            UserDefaults.standard.set(true, forKey: key)
            logger.notice("Dedupe migration removed vocab=\(vocabRemoved, privacy: .public) replacements=\(replacementRemoved, privacy: .public)")
        } catch {
            // Leave the flag unset so a future launch can retry. We intentionally
            // do not roll back the deletes — Core Data discards them when the
            // context is torn down at app exit, and the next attempt starts from
            // a clean slate.
            logger.error("Dedupe migration save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Returns the count of duplicates marked for deletion. Keeps the first entry
    /// (by current fetch order) for each `word.lowercased()` group.
    private static func dedupeVocabulary(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<VocabularyWord>()
        guard let entries = try? context.fetch(descriptor) else { return 0 }

        var seen = Set<String>()
        var removed = 0
        for entry in entries {
            let key = entry.word.lowercased()
            if seen.contains(key) {
                context.delete(entry)
                removed += 1
            } else {
                seen.insert(key)
            }
        }
        return removed
    }

    /// Returns the count of duplicates removed. An entry counts as a duplicate
    /// when every non-empty token in its `originalText` has already been claimed
    /// by an earlier entry. Partial overlaps are preserved on purpose: an entry
    /// that introduces at least one new trigger token is kept and its tokens are
    /// added to the claimed set so later entries can still be deduped against it.
    private static func dedupeWordReplacements(context: ModelContext) -> Int {
        let descriptor = FetchDescriptor<WordReplacement>()
        guard let entries = try? context.fetch(descriptor) else { return 0 }

        var claimedTokens = Set<String>()
        var removed = 0
        for entry in entries {
            let tokens = entry.originalText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }

            guard !tokens.isEmpty else { continue }

            if tokens.allSatisfy({ claimedTokens.contains($0) }) {
                context.delete(entry)
                removed += 1
            } else {
                for token in tokens { claimedTokens.insert(token) }
            }
        }
        return removed
    }
}

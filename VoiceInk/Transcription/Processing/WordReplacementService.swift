import Foundation
import SwiftData
import os

class WordReplacementService {
    static let shared = WordReplacementService()

    /// Per-process compiled-regex cache, keyed by the literal pattern string.
    /// Pattern construction is deterministic per replacement key, so the cache
    /// hit rate is high (the same user keys reappear on every transcription).
    /// Compilation of `NSRegularExpression` is non-trivial; with ~20 user
    /// replacements the savings show up in the hot path.
    private let regexCacheLock = OSAllocatedUnfairLock(initialState: [String: NSRegularExpression]())

    private init() {}

    private func cachedRegex(pattern: String) -> NSRegularExpression? {
        regexCacheLock.withLock { cache in
            if let existing = cache[pattern] {
                return existing
            }
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .useUnicodeWordBoundaries]
            ) else {
                return nil
            }
            cache[pattern] = regex
            return regex
        }
    }

    func applyReplacements(to text: String, using context: ModelContext) -> String {
        let descriptor = FetchDescriptor<WordReplacement>(
            predicate: #Predicate { $0.isEnabled }
        )

        guard let replacements = try? context.fetch(descriptor), !replacements.isEmpty else {
            return text // No replacements to apply
        }

        var modifiedText = text

        // Longest-first so specific triggers match before shorter overlapping ones
        let sortedReplacements = replacements.sorted {
            $0.originalText.count > $1.originalText.count
        }

        // Apply replacements (case-insensitive)
        for replacement in sortedReplacements {
            let originalGroup = replacement.originalText
            let replacementText = replacement.replacementText

            let variants = originalGroup
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .sorted { $0.count > $1.count }

            for original in variants {
                let usesBoundaries = usesWordBoundaries(for: original)

                if usesBoundaries {
                    // Use \b with .useUnicodeWordBoundaries so the boundary follows
                    // Unicode TR#29 — accented letters (é, ñ, ü, ã, ç, ...) and other
                    // letter-class characters count as part of a "word". The previous
                    // implementation used ASCII-only lookarounds (`[a-zA-Z0-9]`), which
                    // treated accented letters as boundaries and over-matched on
                    // adjacency: e.g., replacing "açai" would (incorrectly) fire inside
                    // "açaié" because "é" was not [a-zA-Z0-9]. With Unicode word
                    // boundaries, punctuation and whitespace still serve as boundaries,
                    // exactly as intended in the original comment.
                    let escaped = NSRegularExpression.escapedPattern(for: original)
                    let pattern = "\\b\(escaped)\\b"
                    if let regex = cachedRegex(pattern: pattern) {
                        let range = NSRange(modifiedText.startIndex..., in: modifiedText)
                        modifiedText = regex.stringByReplacingMatches(
                            in: modifiedText,
                            options: [],
                            range: range,
                            withTemplate: replacementText
                        )
                    }
                } else {
                    // Fallback substring replace for non-spaced scripts
                    modifiedText = modifiedText.replacingOccurrences(of: original, with: replacementText, options: .caseInsensitive)
                }
            }
        }

        return modifiedText
    }

    private func usesWordBoundaries(for text: String) -> Bool {
        // Returns false for languages without spaces (CJK, Thai), true for spaced languages
        let nonSpacedScripts: [ClosedRange<UInt32>] = [
            0x3040...0x309F, // Hiragana
            0x30A0...0x30FF, // Katakana
            0x4E00...0x9FFF, // CJK Unified Ideographs
            0xAC00...0xD7AF, // Hangul Syllables
            0x0E00...0x0E7F, // Thai
        ]

        for scalar in text.unicodeScalars {
            for range in nonSpacedScripts {
                if range.contains(scalar.value) {
                    return false
                }
            }
        }

        return true
    }
}

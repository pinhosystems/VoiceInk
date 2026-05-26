import Foundation
import os

/// Applies a `LocalePack`'s normalization pipeline to a transcription string.
/// Pure function: same input + same pack always produces the same output.
/// Two-pass: first the declarative `normalizerRules` in order, then the pack's
/// optional `customNormalize` escape hatch (for transforms regex cannot
/// express — CPF digit validation, number-word arithmetic, etc.).
enum LocaleNormalizer {
    private static let logger = Logger(
        subsystem: "agabo.dev.voiceink",
        category: "LocaleNormalizer"
    )

    /// Runs `pack.normalizerRules` then `pack.customNormalize` against `text`.
    /// In debug builds, logs each rule's description + match count when it fires.
    static func apply(_ text: String, pack: LocalePack) -> String {
        guard !text.isEmpty else { return text }
        let afterRules = apply(text, rules: pack.normalizerRules)
        return pack.customNormalize.map { $0(afterRules) } ?? afterRules
    }

    /// Rules-only entry point. Useful for tests + callers that want the
    /// declarative pass without the pack-level escape hatch.
    static func apply(_ text: String, rules: [NormalizerRule]) -> String {
        guard !rules.isEmpty, !text.isEmpty else { return text }

        var current = text
        for rule in rules {
            let range = NSRange(current.startIndex..<current.endIndex, in: current)
            let matchCount = rule.pattern.numberOfMatches(in: current, options: [], range: range)
            guard matchCount > 0 else { continue }

            current = rule.pattern.stringByReplacingMatches(
                in: current,
                options: [],
                range: range,
                withTemplate: rule.replacement
            )

            #if DEBUG
            logger.debug("rule '\(rule.description, privacy: .public)' fired \(matchCount, privacy: .public) time(s)")
            #endif
        }
        return current
    }
}

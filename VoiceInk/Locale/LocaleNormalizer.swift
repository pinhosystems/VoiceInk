import Foundation
import os

/// Applies a `LocalePack`'s `NormalizerRule[]` to a transcription string.
/// Pure function: same input + same rules always produces the same output.
/// Sequential application — each rule sees the output of the previous one.
enum LocaleNormalizer {
    private static let logger = Logger(
        subsystem: "com.prakashjoshipax.voiceink",
        category: "LocaleNormalizer"
    )

    /// Runs every rule in order against `text`. In debug builds, logs the rule
    /// description and the match count whenever a rule actually fires.
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

import Foundation

struct AIEnhancementOutputFilter {
    /// Pre-compiled patterns that strip provider-side reasoning/thinking blocks.
    /// Compilation of `NSRegularExpression` is non-trivial; keeping these as
    /// `static let` avoids paying the cost on every transcription.
    private static let regexes: [NSRegularExpression] = {
        let patterns = [
            #"(?s)<thinking>(.*?)</thinking>"#,
            #"(?s)<think>(.*?)</think>"#,
            #"(?s)<reasoning>(.*?)</reasoning>"#
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    static func filter(_ text: String) -> String {
        var processedText = text
        for regex in regexes {
            let range = NSRange(processedText.startIndex..., in: processedText)
            processedText = regex.stringByReplacingMatches(
                in: processedText,
                options: [],
                range: range,
                withTemplate: ""
            )
        }
        return processedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

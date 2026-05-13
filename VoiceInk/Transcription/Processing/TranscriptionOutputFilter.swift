import Foundation

struct TranscriptionOutputFilter {
    private static let removePunctuationKey = "RemovePunctuation"
    private static let lowercaseTranscriptionKey = "LowercaseTranscription"
    private static let apostropheLikeCharacters = CharacterSet(charactersIn: "'’‘ʼ＇")
    
    /// Whisper-style non-verbal annotations that legitimately appear inside brackets/parens.
    /// Strip only these — never plain user content like "(o gerente novo)" or "[ver depois]".
    private static let hallucinationKeywords: Set<String> = [
        "music", "music playing", "soft music", "loud music", "upbeat music",
        "instrumental", "instrumental music", "intro music", "outro music",
        "applause", "cheering", "crowd", "chatter", "background noise", "noise",
        "laughter", "laugh", "laughs", "laughing", "chuckle", "chuckles",
        "silence", "pause", "long pause",
        "coughing", "cough", "sneeze", "breathing", "breath", "breathes",
        "sigh", "sighs", "groan", "groans",
        "whispering", "whisper", "muffled",
        "inaudible", "indistinct", "unintelligible",
        "click", "clicking", "tap", "tapping", "thump",
        "intro", "outro", "music ends", "music fades",
        "música", "música ao fundo", "risos", "aplausos", "silêncio",
        "tosse", "suspiro", "inaudível"
    ]

    static func filter(_ text: String) -> String {
        var filteredText = text

        // Remove <TAG>...</TAG> blocks
        let tagBlockPattern = #"<([A-Za-z][A-Za-z0-9:_-]*)[^>]*>[\s\S]*?</\1>"#
        if let regex = try? NSRegularExpression(pattern: tagBlockPattern) {
            let range = NSRange(filteredText.startIndex..., in: filteredText)
            filteredText = regex.stringByReplacingMatches(in: filteredText, options: [], range: range, withTemplate: "")
        }

        // Remove only bracketed/parenthesized Whisper hallucinations whose content
        // matches a known non-verbal annotation. Legitimate parentheticals survive.
        filteredText = removeKnownAnnotations(in: filteredText)

        // Remove filler words (if enabled)
        if FillerWordManager.shared.isEnabled {
            for fillerWord in FillerWordManager.shared.fillerWords {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: fillerWord))\\b[,.]?"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(filteredText.startIndex..., in: filteredText)
                    filteredText = regex.stringByReplacingMatches(in: filteredText, options: [], range: range, withTemplate: "")
                }
            }
        }

        // Clean whitespace
        filteredText = filteredText.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        filteredText = filteredText.trimmingCharacters(in: .whitespacesAndNewlines)

        return filteredText
    }

    static func applyUserCleanupPreferences(_ text: String) -> String {
        let shouldRemovePunctuation = UserDefaults.standard.bool(forKey: removePunctuationKey)
        let shouldLowercase = UserDefaults.standard.bool(forKey: lowercaseTranscriptionKey)

        guard shouldRemovePunctuation || shouldLowercase else {
            return text
        }

        var cleanedText = text
        if shouldRemovePunctuation {
            cleanedText = removePunctuation(from: cleanedText)
        }
        if shouldLowercase {
            cleanedText = cleanedText.lowercased()
        }

        return cleanedText
    }

    static func removePunctuation(from text: String) -> String {
        guard !text.isEmpty else { return text }

        let punctuationSeparators = CharacterSet.punctuationCharacters.subtracting(apostropheLikeCharacters)
        let cleanedScalars = text.unicodeScalars.map { scalar -> String in
            if apostropheLikeCharacters.contains(scalar) {
                return ""
            }

            if punctuationSeparators.contains(scalar) {
                return " "
            }

            return String(scalar)
        }

        return normalizeWhitespace(cleanedScalars.joined())
    }

    /// Strips bracket/paren/brace groups whose entire content is a known hallucination keyword.
    /// Matches case-insensitively and ignores adjective adverbs like "loud" before the keyword.
    private static func removeKnownAnnotations(in text: String) -> String {
        let pairs: [(open: Character, close: Character)] = [("[", "]"), ("(", ")"), ("{", "}")]
        var result = text
        for (open, close) in pairs {
            result = stripAnnotations(in: result, opening: open, closing: close)
        }
        return result
    }

    private static func stripAnnotations(in text: String, opening: Character, closing: Character) -> String {
        guard text.contains(opening) else { return text }
        var output = ""
        output.reserveCapacity(text.count)
        var cursor = text.startIndex
        while let openIdx = text[cursor...].firstIndex(of: opening) {
            output.append(contentsOf: text[cursor..<openIdx])
            guard let closeIdx = text[text.index(after: openIdx)...].firstIndex(of: closing) else {
                output.append(contentsOf: text[openIdx...])
                return output
            }
            let inner = text[text.index(after: openIdx)..<closeIdx]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            if isHallucination(inner) {
                cursor = text.index(after: closeIdx)
            } else {
                output.append(contentsOf: text[openIdx...closeIdx])
                cursor = text.index(after: closeIdx)
            }
        }
        output.append(contentsOf: text[cursor...])
        return output
    }

    private static func isHallucination(_ candidate: String) -> Bool {
        guard !candidate.isEmpty else { return false }
        if hallucinationKeywords.contains(candidate) { return true }
        // Allow simple adjective prefixes (e.g. "loud applause", "soft chuckling")
        let words = candidate.split(separator: " ")
        guard words.count >= 2 else { return false }
        let tail = words.dropFirst().joined(separator: " ")
        return hallucinationKeywords.contains(tail)
    }

    private static func normalizeWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"[^\S\r\n]{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[ \t]+\n"#, with: "\n", options: .regularExpression)
            .replacingOccurrences(of: #"\n[ \t]+"#, with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 

import Foundation

enum PunctuationCleanupMode: String, Codable, CaseIterable, Identifiable {
    case keep = "keep"
    case removeAll = "removeAll"
    case removeTrailingPeriod = "removeTrailingPeriod"

    static let userDefaultsKey = "PunctuationCleanupMode"
    static let legacyRemovePunctuationKey = "RemovePunctuation"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .keep:
            return "Keep"
        case .removeAll:
            return "Remove all"
        case .removeTrailingPeriod:
            return "Remove trailing period"
        }
    }

    static func current(in defaults: UserDefaults = .standard) -> PunctuationCleanupMode {
        if let rawValue = defaults.string(forKey: userDefaultsKey),
           let mode = PunctuationCleanupMode(rawValue: rawValue) {
            return mode
        }

        return defaults.bool(forKey: legacyRemovePunctuationKey) ? .removeAll : .keep
    }

    static func setCurrent(_ mode: PunctuationCleanupMode, in defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: userDefaultsKey)
        defaults.set(mode == .removeAll, forKey: legacyRemovePunctuationKey)
    }

    static func migrateLegacyUserDefaultIfNeeded(in defaults: UserDefaults = .standard) {
        if let rawValue = defaults.string(forKey: userDefaultsKey),
           PunctuationCleanupMode(rawValue: rawValue) != nil {
            return
        }

        setCurrent(defaults.bool(forKey: legacyRemovePunctuationKey) ? .removeAll : .keep, in: defaults)
    }
}

struct TranscriptionOutputFilter {
    private static let lowercaseTranscriptionKey = "LowercaseTranscription"
    private static let apostropheLikeCharacters = CharacterSet(charactersIn: "'’‘ʼ＇")
    
    /// Whisper-style non-verbal annotations that legitimately appear inside brackets/parens.
    /// Strip only these — never plain user content like "(o gerente novo)" or "[ver depois]".
    private static let hallucinationKeywords: Set<String> = [
        // English
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
        // Português brasileiro: Whisper costuma alucinar essas marcações entre
        // colchetes/parênteses em transcrições pt-BR (especialmente em silêncios
        // ou áudio com ruído de fundo). Cobre singular/plural, gerúndio e variações.
        "música", "músicas", "música ao fundo", "música de fundo", "música tocando",
        "música suave", "música alta", "música animada", "música instrumental",
        "abertura", "encerramento", "vinheta", "trilha", "trilha sonora",
        "risos", "risada", "risadas", "rindo", "gargalhada", "gargalhadas",
        "aplausos", "palmas", "vivas",
        "silêncio", "pausa", "longa pausa", "pausa longa",
        "tosse", "tossindo", "tossiu", "espirro", "espirra", "espirrando",
        "respiração", "respira", "respirando", "suspiro", "suspirando", "suspira", "suspiros",
        "gemido", "gemidos", "gemendo",
        "sussurro", "sussurrando", "sussurra", "abafado",
        "inaudível", "ininteligível", "incompreensível", "indistinto",
        "estalo", "estalido", "clique", "batida", "batidas",
        "barulho", "barulhos", "ruído", "ruídos", "ruído de fundo", "barulho de fundo",
        "burburinho", "conversa", "conversa de fundo", "conversas",
        "ronco", "roncos", "roncando",
        "música encerra", "música termina", "música começa", "fim da música"
    ]

    static func filter(_ text: String) -> String {
        var filteredText = text

        // Remove only bracketed/parenthesized Whisper hallucinations whose content
        // matches a known non-verbal annotation. Legitimate parentheticals survive.
        //
        // Note: a previous version of this filter also stripped any <TAG>...</TAG>
        // block via regex. That happens BEFORE AI enhancement (which has its own
        // <thinking>/<think>/<reasoning> filter), so it ended up silently deleting
        // legitimate dictated content such as HTML, JSX, or XML samples.
        filteredText = removeKnownAnnotations(in: filteredText)

        // Remove filler words (if enabled). Uses `effectiveFillerWords` so that the
        // pt-BR set ("né", "tipo", "sei lá", ...) is included automatically when the
        // selected language begins with "pt", without mutating the user's saved list.
        if FillerWordManager.shared.isEnabled {
            // Sort longest-first so multi-word fillers ("tipo assim") match before
            // their substrings ("tipo"); avoids leaving an orphaned "assim".
            let words = FillerWordManager.shared.effectiveFillerWords
                .sorted { $0.count > $1.count }
            for fillerWord in words {
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: fillerWord))\\b[,.]?"
                if let regex = try? NSRegularExpression(
                    pattern: pattern,
                    options: [.caseInsensitive, .useUnicodeWordBoundaries]
                ) {
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
        let punctuationMode = PunctuationCleanupMode.current()
        let shouldLowercase = UserDefaults.standard.bool(forKey: lowercaseTranscriptionKey)

        return applyCleanupPreferences(text, punctuationMode: punctuationMode, shouldLowercase: shouldLowercase)
    }

    static func applyCleanupPreferences(_ text: String, punctuationMode: PunctuationCleanupMode, shouldLowercase: Bool) -> String {
        guard punctuationMode != .keep || shouldLowercase else {
            return text
        }

        var cleanedText = text
        switch punctuationMode {
        case .keep:
            break
        case .removeAll:
            cleanedText = removePunctuation(from: cleanedText)
        case .removeTrailingPeriod:
            cleanedText = removeTrailingPeriod(from: cleanedText)
        }

        if shouldLowercase {
            cleanedText = cleanedText.lowercased()
        }

        return cleanedText
    }

    static func removeTrailingPeriod(from text: String) -> String {
        guard !text.isEmpty else { return text }

        let trailingWhitespace = text.reversed().prefix { $0.isWhitespace }
        let trimmedEndIndex = text.index(text.endIndex, offsetBy: -trailingWhitespace.count)
        guard trimmedEndIndex > text.startIndex else { return text }

        let lastCharIndex = text.index(before: trimmedEndIndex)
        guard text[lastCharIndex] == "." else { return text }

        if lastCharIndex > text.startIndex {
            let previousCharIndex = text.index(before: lastCharIndex)
            guard text[previousCharIndex] != "." else { return text }
        }

        var result = text
        result.remove(at: lastCharIndex)
        return result
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

import Foundation
import os

/// Brazilian-Portuguese-specific text normalization applied AFTER raw STT and word
/// replacements, but BEFORE the AI enhancement step. Operates only when the user's
/// selected language begins with "pt" (Whisper "pt", Apple "pt-BR"/"pt-PT") AND the
/// opt-in `BrazilianNormalizationEnabled` UserDefault is set.
///
/// Each rule is intentionally conservative: a regex that matches confidently or
/// not at all. The goal is to handle the *high-frequency* cases (CPF, CNPJ, CEP,
/// "duas horas e meia", "cinquenta por cento") without ever risking silent
/// corruption of legitimate text. Anything ambiguous falls through unchanged.
///
/// Pipeline placement: inside `TranscriptionPipeline.run` between
/// `WordReplacementService.applyReplacements` and `applyUserCleanupPreferences`,
/// so the LLM enhancement sees already-normalized identifiers and numbers.
enum BrazilianTextNormalizer {
    static let enabledKey = "BrazilianNormalizationEnabled"

    private static let logger = Logger(
        subsystem: "com.prakashjoshipax.voiceink",
        category: "BrazilianTextNormalizer"
    )

    /// Maps a Portuguese number word (0..29) to its numeric form. Capped at 29
    /// because the hour-normalization is the main consumer; spelled-out larger
    /// numbers ("cinquenta", "cem") are handled only inside percentage and money
    /// patterns where context is unambiguous.
    private static let basicNumberWords: [String: Int] = [
        "zero": 0,
        "uma": 1, "um": 1,
        "duas": 2, "dois": 2,
        "três": 3, "tres": 3,
        "quatro": 4,
        "cinco": 5,
        "seis": 6,
        "sete": 7,
        "oito": 8,
        "nove": 9,
        "dez": 10,
        "onze": 11,
        "doze": 12,
        "treze": 13,
        "catorze": 14, "quatorze": 14,
        "quinze": 15,
        "dezesseis": 16, "dezasseis": 16,
        "dezessete": 17, "dezassete": 17,
        "dezoito": 18,
        "dezenove": 19, "dezanove": 19,
        "vinte": 20,
        "vinte e um": 21, "vinte e uma": 21,
        "vinte e dois": 22, "vinte e duas": 22,
        "vinte e três": 23, "vinte e tres": 23,
        "vinte e quatro": 24,
        "vinte e cinco": 25,
        "vinte e seis": 26,
        "vinte e sete": 27,
        "vinte e oito": 28,
        "vinte e nove": 29
    ]

    /// Larger round numbers used in percent and currency phrases.
    private static let largerNumberWords: [String: Int] = [
        "trinta": 30, "quarenta": 40, "cinquenta": 50, "cinqüenta": 50,
        "sessenta": 60, "setenta": 70, "oitenta": 80, "noventa": 90,
        "cem": 100, "cento": 100, "duzentos": 200, "trezentos": 300,
        "quatrocentos": 400, "quinhentos": 500, "seiscentos": 600,
        "setecentos": 700, "oitocentos": 800, "novecentos": 900, "mil": 1000
    ]

    /// True when normalization should run for the current settings. Cheap; called
    /// once per transcription from the pipeline.
    static func isEnabled(for language: String?) -> Bool {
        guard let language, language.lowercased().hasPrefix("pt") else { return false }
        // Default ON when pt — if the user explicitly disables it the key is set false.
        if UserDefaults.standard.object(forKey: enabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: enabledKey)
    }

    static func normalize(_ text: String) -> String {
        var result = text
        result = normalizeCNPJ(result)
        result = normalizeCPF(result)
        result = normalizeCEP(result)
        result = normalizePhone(result)
        result = normalizeHoursAndHalf(result)
        result = normalizeHoursWithPartOfDay(result)
        result = normalizePercent(result)
        result = normalizeDecimal(result)
        result = normalizeCurrency(result)
        return result
    }

    // MARK: - Identifiers

    /// Detects standalone CPF-like sequences (11 digits, possibly separated by
    /// spaces, dots, or dashes) and rewrites them as "000.000.000-00". Skips when
    /// the surrounding context already contains a dot or slash from a longer
    /// identifier (CNPJ has 14 digits and runs first).
    private static func normalizeCPF(_ text: String) -> String {
        let pattern = #"(?<![\d./-])(\d[\d .-]{9,17}\d)(?![\d./-])"#
        return rewriteMatching(text, pattern: pattern) { match in
            let digits = match.filter { $0.isNumber }
            guard digits.count == 11 else { return nil }
            return formatCPF(digits)
        }
    }

    private static func normalizeCNPJ(_ text: String) -> String {
        let pattern = #"(?<![\d./-])(\d[\d ./-]{12,22}\d)(?![\d./-])"#
        return rewriteMatching(text, pattern: pattern) { match in
            let digits = match.filter { $0.isNumber }
            guard digits.count == 14 else { return nil }
            return formatCNPJ(digits)
        }
    }

    private static func normalizeCEP(_ text: String) -> String {
        let pattern = #"(?<![\d./-])(\d[\d -]{6,10}\d)(?![\d./-])"#
        return rewriteMatching(text, pattern: pattern) { match in
            let digits = match.filter { $0.isNumber }
            guard digits.count == 8 else { return nil }
            // Only format when the original had a "cep" keyword nearby, or when the
            // user clearly spaced it as a postal code. Skipping the keyword check
            // here is safer because the surrounding pattern bounds already exclude
            // longer numbers; an 8-digit standalone block is overwhelmingly a CEP
            // in Brazilian dictation contexts.
            let prefix = digits.prefix(5)
            let suffix = digits.suffix(3)
            return "\(prefix)-\(suffix)"
        }
    }

    /// Brazilian mobile: "(DD) 9XXXX-XXXX" (11 digits, area code + 9 + 8 digits).
    /// Brazilian landline: "(DD) XXXX-XXXX" (10 digits). Both formats are emitted
    /// from raw 10/11-digit blocks separated by spaces.
    private static func normalizePhone(_ text: String) -> String {
        let pattern = #"(?<![\d./-])(?:(?:\(\d{2}\)|\d{2})\s?9?\s?\d{4}[\s-]?\d{4})(?![\d./-])"#
        return rewriteMatching(text, pattern: pattern) { match in
            let digits = match.filter { $0.isNumber }
            if digits.count == 11 {
                let area = digits.prefix(2)
                let first = digits.dropFirst(2).prefix(5)
                let last = digits.suffix(4)
                return "(\(area)) \(first)-\(last)"
            }
            if digits.count == 10 {
                let area = digits.prefix(2)
                let first = digits.dropFirst(2).prefix(4)
                let last = digits.suffix(4)
                return "(\(area)) \(first)-\(last)"
            }
            return nil
        }
    }

    private static func formatCPF(_ digits: String) -> String {
        let s = Array(digits)
        return "\(s[0])\(s[1])\(s[2]).\(s[3])\(s[4])\(s[5]).\(s[6])\(s[7])\(s[8])-\(s[9])\(s[10])"
    }

    private static func formatCNPJ(_ digits: String) -> String {
        let s = Array(digits)
        return "\(s[0])\(s[1]).\(s[2])\(s[3])\(s[4]).\(s[5])\(s[6])\(s[7])/\(s[8])\(s[9])\(s[10])\(s[11])-\(s[12])\(s[13])"
    }

    // MARK: - Hours

    /// "duas horas e meia" → "2h30"; "três e quinze" → "3h15"; "dez horas" → "10h".
    /// Conservative: only matches when "hora(s)" or "e" with a number-word minute is
    /// present, so plain "duas" / "três" stay as words.
    private static func normalizeHoursAndHalf(_ text: String) -> String {
        let numberAlternation = orderedAlternation(basicNumberWords.keys)
        // "X (horas)? e meia/quinze/trinta/45"
        let pattern = #"\b(\#(numberAlternation))(?:\s+horas?)?\s+e\s+(meia|quinze|trinta|quarenta\s+e\s+cinco|\d{1,2})\b"#
        return rewriteRegex(text, pattern: pattern) { groups in
            guard let hourWord = groups[1]?.lowercased(),
                  let minuteRaw = groups[2]?.lowercased(),
                  let hour = basicNumberWords[hourWord]
            else { return nil }
            let minute = minuteFromPhrase(minuteRaw)
            guard let minute else { return nil }
            return String(format: "%dh%02d", hour, minute)
        }
    }

    /// "duas horas da tarde" → "14h"; "dez da manhã" → "10h"; "oito da noite" → "20h".
    private static func normalizeHoursWithPartOfDay(_ text: String) -> String {
        let numberAlternation = orderedAlternation(basicNumberWords.keys)
        let pattern = #"\b(\#(numberAlternation))(?:\s+horas?)?\s+(?:da\s+|de\s+)(manhã|manha|tarde|noite|madrugada)\b"#
        return rewriteRegex(text, pattern: pattern) { groups in
            guard let hourWord = groups[1]?.lowercased(),
                  let partOfDay = groups[2]?.lowercased(),
                  let raw = basicNumberWords[hourWord]
            else { return nil }
            let hour: Int
            switch partOfDay {
            case "manhã", "manha", "madrugada":
                hour = raw == 12 ? 0 : raw
            case "tarde":
                hour = raw < 12 ? raw + 12 : raw
            case "noite":
                if raw == 12 { hour = 0 } // midnight ("doze da noite")
                else if raw <= 5 { hour = raw } // already past midnight
                else if raw < 12 { hour = raw + 12 }
                else { hour = raw }
            default:
                hour = raw
            }
            return String(format: "%dh", hour)
        }
    }

    private static func minuteFromPhrase(_ phrase: String) -> Int? {
        switch phrase {
        case "meia": return 30
        case "quinze": return 15
        case "trinta": return 30
        case "quarenta e cinco": return 45
        default:
            if let n = Int(phrase), n >= 0, n < 60 { return n }
            return nil
        }
    }

    // MARK: - Percent

    /// "cinquenta por cento" → "50%"; "dez por cento" → "10%"; "100 por cento" → "100%".
    private static func normalizePercent(_ text: String) -> String {
        let combined = basicNumberWords.merging(largerNumberWords) { a, _ in a }
        let alternation = orderedAlternation(combined.keys)
        let wordPattern = #"\b(\#(alternation))\s+por\s+cento\b"#
        var result = rewriteRegex(text, pattern: wordPattern) { groups in
            guard let word = groups[1]?.lowercased(),
                  let value = combined[word]
            else { return nil }
            return "\(value)%"
        }
        // Numeric form: "50 por cento" → "50%"
        let digitPattern = #"\b(\d{1,3})\s+por\s+cento\b"#
        result = rewriteRegex(result, pattern: digitPattern) { groups in
            guard let digits = groups[1] else { return nil }
            return "\(digits)%"
        }
        return result
    }

    // MARK: - Decimal "X ponto Y" → "X,Y"

    /// "três ponto cinco" → "3,5"; "10 ponto 5" → "10,5". Operates only when both
    /// sides are clearly numeric (digits or basic number words 0..29). Skips when
    /// "ponto" follows punctuation that suggests address/version usage.
    private static func normalizeDecimal(_ text: String) -> String {
        // Numeric on both sides
        let numericPattern = #"\b(\d{1,4})\s+ponto\s+(\d{1,4})\b"#
        var result = rewriteRegex(text, pattern: numericPattern) { groups in
            guard let left = groups[1], let right = groups[2] else { return nil }
            return "\(left),\(right)"
        }
        // Word on left, word or digit on right
        let alternation = orderedAlternation(basicNumberWords.keys)
        let wordPattern = #"\b(\#(alternation))\s+ponto\s+(\#(alternation)|\d{1,4})\b"#
        result = rewriteRegex(result, pattern: wordPattern) { groups in
            guard let leftWord = groups[1]?.lowercased(),
                  let left = basicNumberWords[leftWord]
            else { return nil }
            let rightRaw = groups[2]?.lowercased() ?? ""
            let right: String
            if let n = basicNumberWords[rightRaw] { right = String(n) }
            else { right = rightRaw }
            return "\(left),\(right)"
        }
        return result
    }

    // MARK: - Currency

    /// "R$ 100" + trailing "e cinquenta centavos"|"e cinquenta" → "R$ 100,50".
    /// "100 reais" → "R$ 100"; "cem reais" → "R$ 100".
    private static func normalizeCurrency(_ text: String) -> String {
        // "100 reais [e cinquenta centavos]" or just "100 reais"
        let centavoPattern = #"\b(\d{1,9})\s+reais(?:\s+e\s+(\d{1,2})\s+centavos)?\b"#
        var result = rewriteRegex(text, pattern: centavoPattern) { groups in
            guard let inteiros = groups[1] else { return nil }
            let withDots = insertThousandsSeparator(inteiros)
            if let cents = groups[2], let n = Int(cents), n > 0 {
                return "R$ \(withDots),\(String(format: "%02d", n))"
            }
            return "R$ \(withDots)"
        }
        // Word forms: "cem reais", "mil reais", "cinquenta reais"
        let combined = basicNumberWords.merging(largerNumberWords) { a, _ in a }
        let alternation = orderedAlternation(combined.keys)
        let wordPattern = #"\b(\#(alternation))\s+reais\b"#
        result = rewriteRegex(result, pattern: wordPattern) { groups in
            guard let word = groups[1]?.lowercased(),
                  let value = combined[word]
            else { return nil }
            return "R$ \(insertThousandsSeparator(String(value)))"
        }
        return result
    }

    private static func insertThousandsSeparator(_ digits: String) -> String {
        guard digits.count > 3 else { return digits }
        var chars = Array(digits.reversed())
        var out = ""
        for (i, c) in chars.enumerated() {
            if i > 0 && i % 3 == 0 { out.append(".") }
            out.append(c)
        }
        chars.removeAll()
        return String(out.reversed())
    }

    // MARK: - Regex helpers

    /// Returns an alternation pattern with longest entries first, so that
    /// "vinte e três" matches before "vinte". Without this, the alternation greedily
    /// picks the first viable branch and leaves trailing words orphaned.
    private static func orderedAlternation<S: Sequence>(_ words: S) -> String where S.Element == String {
        let escaped = words
            .sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
        return escaped
    }

    /// Applies a regex with a `transform(match) -> replacement?` closure: when the
    /// closure returns nil, the original match is preserved. Used by patterns whose
    /// matches may or may not actually parse (e.g., 11-digit block could be CPF).
    private static func rewriteMatching(
        _ text: String,
        pattern: String,
        transform: (String) -> String?
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.useUnicodeWordBoundaries]) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        var output = ""
        var cursor = text.startIndex
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match, let matchRange = Range(match.range, in: text) else { return }
            let candidate = String(text[matchRange])
            output.append(contentsOf: text[cursor..<matchRange.lowerBound])
            if let replacement = transform(candidate) {
                output.append(replacement)
            } else {
                output.append(candidate)
            }
            cursor = matchRange.upperBound
        }
        output.append(contentsOf: text[cursor..<text.endIndex])
        return output
    }

    /// Like `rewriteMatching` but exposes capture groups (1..n). Group 0 is the
    /// whole match.
    private static func rewriteRegex(
        _ text: String,
        pattern: String,
        transform: ([Int: String]) -> String?
    ) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive, .useUnicodeWordBoundaries]
        ) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        var output = ""
        var cursor = text.startIndex
        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match, let matchRange = Range(match.range, in: text) else { return }
            output.append(contentsOf: text[cursor..<matchRange.lowerBound])
            var groups: [Int: String] = [:]
            for i in 0..<match.numberOfRanges {
                if let r = Range(match.range(at: i), in: text) {
                    groups[i] = String(text[r])
                }
            }
            let original = String(text[matchRange])
            output.append(transform(groups) ?? original)
            cursor = matchRange.upperBound
        }
        output.append(contentsOf: text[cursor..<text.endIndex])
        return output
    }
}

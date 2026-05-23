import Foundation

enum TranscriptionLanguageSupport {
    private static let assemblyAIRealtimeLanguageCodes = ["en", "es", "de", "fr", "pt", "it"]

    private static let assemblyAIBatchLanguageCodes = [
        "en", "en_au", "en_uk", "en_us", "es", "fr", "de", "it", "pt", "nl",
        "hi", "ja", "zh", "fi", "ko", "pl", "ru", "tr", "uk", "vi", "af",
        "sq", "am", "ar", "hy", "as", "az", "ba", "eu", "be", "bn", "bs",
        "br", "bg", "my", "ca", "hr", "cs", "da", "et", "fo", "gl", "ka",
        "el", "gu", "ht", "ha", "haw", "he", "hu", "is", "id", "jw", "kn",
        "kk", "km", "lo", "la", "lv", "ln", "lt", "lb", "mk", "mg", "ms",
        "ml", "mt", "mi", "mr", "mn", "ne", "no", "nn", "oc", "pa", "ps",
        "fa", "ro", "sa", "sr", "sn", "sd", "si", "sk", "sl", "so", "su",
        "sw", "sv", "de_ch", "tl", "tg", "ta", "tt", "te", "th", "bo",
        "tk", "ur", "uz", "cy", "yi", "yo"
    ]

    static func languages(for model: any TranscriptionModel) -> [String: String] {
        if model.provider == .assemblyAI {
            return assemblyAILanguages(usesRealtime: assemblyAIUsesRealtime(for: model))
        }

        return model.supportedLanguages
    }

    static func validLanguageOrFallback(_ language: String?, for model: any TranscriptionModel) -> String {
        let languages = languages(for: model)

        if let language, languages[language] != nil {
            return language
        }

        // Apple Native uses BCP-47 ("pt-BR", "en-US"), while every other provider
        // uses Whisper-style 2-letter codes ("pt", "en"). When switching between
        // providers, map the user's stripped/region-tagged code to the closest
        // equivalent so a Brazilian user who chose "pt" once doesn't see Apple
        // Native silently fall back to English.
        if model.provider == .nativeApple, let language {
            if let mapped = mapToAppleNative(language, in: languages) {
                return mapped
            }
            if languages["en-US"] != nil {
                return "en-US"
            }
        }

        // Inverse direction: a user on Apple Native chose "pt-BR" and switched to a
        // Whisper-based provider. Strip the region tag to land on the 2-letter code
        // that Whisper, OpenAI, Groq, etc. expect.
        if let language, language.contains("-") {
            let base = String(language.prefix { $0 != "-" })
            if languages[base] != nil {
                return base
            }
        }

        if languages["auto"] != nil {
            return "auto"
        }

        if languages["en"] != nil {
            return "en"
        }

        return languages.keys.sorted { lhs, rhs in
            languages[lhs, default: lhs] < languages[rhs, default: rhs]
        }.first ?? "en"
    }

    /// Maps a Whisper-style or region-less code to the most natural Apple Native
    /// BCP-47 identifier. For ambiguous bases (e.g., "pt" → pt-BR or pt-PT), the
    /// system locale is consulted: if it starts with the same base and the region
    /// is supported, that region wins; otherwise a sensible Brazilian-/US-first
    /// default is used. This favors the (much larger) pt-BR user base without
    /// stealing the choice from a Portuguese speaker whose system says pt-PT.
    private static func mapToAppleNative(_ language: String, in available: [String: String]) -> String? {
        let normalized = language.lowercased()

        // Already a regioned code (case-insensitive match)
        if let exact = available.keys.first(where: { $0.lowercased() == normalized }) {
            return exact
        }

        // Try system locale first when the base matches.
        let systemRegion = Locale.current.region?.identifier
            ?? Locale.current.identifier.split(separator: "_").dropFirst().first.map(String.init)
        if let systemRegion {
            let candidate = "\(normalized)-\(systemRegion.uppercased())"
            if let match = available.keys.first(where: { $0.lowercased() == candidate.lowercased() }) {
                return match
            }
        }

        // Curated defaults for the common cases. pt → pt-BR because the Brazilian
        // user base dwarfs the Portuguese one; en → en-US for parity with Whisper's
        // "en" semantics; es → es-ES; fr → fr-FR; de → de-DE; it → it-IT;
        // zh → zh-CN.
        let defaultsByBase: [String: String] = [
            "pt": "pt-BR",
            "en": "en-US",
            "es": "es-ES",
            "fr": "fr-FR",
            "de": "de-DE",
            "it": "it-IT",
            "zh": "zh-CN"
        ]
        if let preferred = defaultsByBase[normalized],
           let match = available.keys.first(where: { $0.lowercased() == preferred.lowercased() }) {
            return match
        }

        // Last resort: any locale whose base matches.
        let basePrefix = "\(normalized)-"
        return available.keys.first { $0.lowercased().hasPrefix(basePrefix) }
    }

    private static func assemblyAILanguages(usesRealtime: Bool) -> [String: String] {
        let codes = usesRealtime ? assemblyAIRealtimeLanguageCodes : assemblyAIBatchLanguageCodes
        var filtered = LanguageDictionary.all.filter { codes.contains($0.key) }
        filtered["auto"] = "Auto-detect"
        return filtered
    }

    private static func assemblyAIUsesRealtime(for model: any TranscriptionModel) -> Bool {
        guard model.provider == .assemblyAI, model.supportsStreaming else {
            return false
        }

        if let cloudProvider = CloudProviderRegistry.provider(for: model.provider), cloudProvider.isStreamingOnly {
            return true
        }

        return UserDefaults.standard.object(forKey: "streaming-enabled-\(model.name)") as? Bool ?? true
    }
}

enum LanguageDictionary {
    private static let whisperLanguageCodes: Set<String> = [
        "auto",
        "af", "am", "ar", "as", "az", "ba", "be", "bg", "bn", "bo",
        "br", "bs", "ca", "cs", "cy", "da", "de", "el", "en", "es",
        "et", "eu", "fa", "fi", "fo", "fr", "gl", "gu", "ha", "haw",
        "he", "hi", "hr", "ht", "hu", "hy", "id", "is", "it", "ja",
        "jw", "ka", "kk", "km", "kn", "ko", "la", "lb", "ln", "lo",
        "lt", "lv", "mg", "mi", "mk", "ml", "mn", "mr", "ms", "mt",
        "my", "ne", "nl", "nn", "no", "oc", "pa", "pl", "ps", "pt",
        "ro", "ru", "sa", "sd", "si", "sk", "sl", "sn", "so", "sq",
        "sr", "su", "sv", "sw", "ta", "te", "tg", "th", "tk", "tl",
        "tr", "tt", "uk", "ur", "uz", "vi", "yi", "yo", "yue", "zh"
    ]

    static func forProvider(isMultilingual: Bool, provider: ModelProvider = .whisper) -> [String: String] {
        if !isMultilingual {
            return ["en": "English"]
        }

        if let cloudProvider = CloudProviderRegistry.provider(for: provider) {
            guard let codes = cloudProvider.languageCodes else {
                return all
            }
            var filtered = all.filter { codes.contains($0.key) }
            if cloudProvider.includesAutoDetect { filtered["auto"] = "Auto-detect" }
            return filtered
        }

        switch provider {
        case .whisper:
            return languages(matching: whisperLanguageCodes)

        case .nativeApple:
            return appleNative

        case .fluidAudio:
            let codes = [
                "bg", "cs", "da", "de", "el", "en", "es", "et", "fi", "fr",
                "hr", "hu", "it", "lt", "lv", "mt", "nl", "pl", "pt", "ro",
                "ru", "sk", "sl", "sv", "uk"
            ]
            var filtered = all.filter { codes.contains($0.key) }
            filtered["auto"] = "Auto-detect"
            return filtered

        default:
            return all
        }
    }

    private static func languages(matching codes: Set<String>) -> [String: String] {
        all.filter { codes.contains($0.key) }
    }

    // Apple Native Speech languages in BCP-47 format.
    // Queried from SpeechTranscriber.supportedLocales on macOS 26.4.
    static let appleNative: [String: String] = [
        "de-DE": "German (Germany)",
        "de-AT": "German (Austria)",
        "de-CH": "German (Switzerland)",
        "en-AU": "English (Australia)",
        "en-CA": "English (Canada)",
        "en-GB": "English (United Kingdom)",
        "en-IE": "English (Ireland)",
        "en-IN": "English (India)",
        "en-NZ": "English (New Zealand)",
        "en-SG": "English (Singapore)",
        "en-US": "English (United States)",
        "en-ZA": "English (South Africa)",
        "es-CL": "Spanish (Chile)",
        "es-ES": "Spanish (Spain)",
        "es-MX": "Spanish (Mexico)",
        "es-US": "Spanish (United States)",
        "fr-BE": "French (Belgium)",
        "fr-CA": "French (Canada)",
        "fr-CH": "French (Switzerland)",
        "fr-FR": "French (France)",
        "it-CH": "Italian (Switzerland)",
        "it-IT": "Italian (Italy)",
        "ja-JP": "Japanese (Japan)",
        "ko-KR": "Korean (South Korea)",
        "pt-BR": "Portuguese (Brazil)",
        "pt-PT": "Portuguese (Portugal)",
        "yue-CN": "Cantonese (China mainland)",
        "zh-CN": "Chinese (China mainland)",
        "zh-HK": "Chinese (Hong Kong)",
        "zh-TW": "Chinese (Taiwan)"
    ]

    static let all: [String: String] = [
        "auto": "Auto-detect",
        "af": "Afrikaans",
        "am": "Amharic",
        "ar": "Arabic",
        "as": "Assamese",
        "az": "Azerbaijani",
        "ba": "Bashkir",
        "be": "Belarusian",
        "bg": "Bulgarian",
        "bn": "Bengali",
        "bo": "Tibetan",
        "br": "Breton",
        "bs": "Bosnian",
        "ca": "Catalan",
        "cs": "Czech",
        "cy": "Welsh",
        "da": "Danish",
        "de": "German",
        "de_ch": "Swiss German",
        "el": "Greek",
        "en": "English",
        "en_au": "Australian English",
        "en_uk": "British English",
        "en_us": "US English",
        "es": "Spanish",
        "et": "Estonian",
        "eu": "Basque",
        "fa": "Persian",
        "fi": "Finnish",
        "fil": "Filipino",
        "fo": "Faroese",
        "fr": "French",
        "ga": "Irish",
        "gl": "Galician",
        "gu": "Gujarati",
        "ha": "Hausa",
        "haw": "Hawaiian",
        "he": "Hebrew",
        "hi": "Hindi",
        "hr": "Croatian",
        "ht": "Haitian Creole",
        "hu": "Hungarian",
        "hy": "Armenian",
        "id": "Indonesian",
        "ig": "Igbo",
        "is": "Icelandic",
        "it": "Italian",
        "ja": "Japanese",
        "jw": "Javanese",
        "ka": "Georgian",
        "kk": "Kazakh",
        "km": "Khmer",
        "kn": "Kannada",
        "ko": "Korean",
        "ku": "Kurdish",
        "ky": "Kyrgyz",
        "la": "Latin",
        "lb": "Luxembourgish",
        "ln": "Lingala",
        "lo": "Lao",
        "lt": "Lithuanian",
        "lv": "Latvian",
        "mg": "Malagasy",
        "mi": "Maori",
        "mk": "Macedonian",
        "ml": "Malayalam",
        "mn": "Mongolian",
        "mr": "Marathi",
        "ms": "Malay",
        "mt": "Maltese",
        "my": "Myanmar",
        "ne": "Nepali",
        "nl": "Dutch",
        "nn": "Norwegian Nynorsk",
        "no": "Norwegian",
        "oc": "Occitan",
        "or": "Odia",
        "pa": "Punjabi",
        "pl": "Polish",
        "ps": "Pashto",
        "pt": "Portuguese",
        "ro": "Romanian",
        "ru": "Russian",
        "sa": "Sanskrit",
        "sd": "Sindhi",
        "si": "Sinhala",
        "sk": "Slovak",
        "sl": "Slovenian",
        "sn": "Shona",
        "so": "Somali",
        "sq": "Albanian",
        "sr": "Serbian",
        "su": "Sundanese",
        "sv": "Swedish",
        "sw": "Swahili",
        "ta": "Tamil",
        "te": "Telugu",
        "tg": "Tajik",
        "th": "Thai",
        "tk": "Turkmen",
        "tl": "Tagalog",
        "tr": "Turkish",
        "tt": "Tatar",
        "uk": "Ukrainian",
        "ur": "Urdu",
        "uz": "Uzbek",
        "vi": "Vietnamese",
        "wo": "Wolof",
        "xh": "Xhosa",
        "yi": "Yiddish",
        "yo": "Yoruba",
        "yue": "Cantonese",
        "zh": "Chinese",
        "zu": "Zulu"
    ]
}

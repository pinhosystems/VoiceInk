import Foundation


/// Domain-specific seed presets for Brazilian Portuguese. Each preset is a dense
/// initial_prompt that exposes Whisper to vocabulary and formatting typical of a
/// given context (clinical, legal, technical, corporate). Whisper uses the
/// initial_prompt as a soft prior, so seeding it with domain words measurably
/// improves recognition on those terms without needing a fine-tuned model.
///
/// Stored as `WhisperPromptDomain` in UserDefaults. The default `general` falls
/// back to the previous broad seed.
enum WhisperPromptDomain: String, CaseIterable, Identifiable {
    case general
    case technical
    case medical
    case legal
    case corporate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: return "Geral"
        case .technical: return "Técnico / Programação"
        case .medical: return "Médico / Clínico"
        case .legal: return "Jurídico"
        case .corporate: return "Corporativo / Reunião"
        }
    }
}

@MainActor
class WhisperPrompt: ObservableObject {
    @Published var transcriptionPrompt: String = UserDefaults.standard.string(forKey: "TranscriptionPrompt") ?? ""

    static let domainKey = "WhisperPromptDomain"

    private let customPromptsKey = "CustomLanguagePrompts"
    
    // Store user-customized prompts
    private var customPrompts: [String: String] = [:]
    
    // Language-specific base prompts
    private let languagePrompts: [String: String] = [
        // English
        "en": "Hello, how are you doing? Nice to meet you.",
        
        // Asian Languages
        "hi": "नमस्ते, कैसे हैं आप? आपसे मिलकर अच्छा लगा।",
        "bn": "নমস্কার, কেমন আছেন? আপনার সাথে দেখা হয়ে ভালো লাগলো।",
        "ja": "こんにちは、お元気ですか？お会いできて嬉しいです。",
        "ko": "안녕하세요, 잘 지내시나요? 만나서 반갑습니다.",
        "zh": "你好，最近好吗？见到你很高兴。",
        "th": "สวัสดีครับ/ค่ะ, สบายดีไหม? ยินดีที่ได้พบคุณ",
        "vi": "Xin chào, bạn khỏe không? Rất vui được gặp bạn.",
        "yue": "你好，最近點呀？見到你好開心。",
        
        // European Languages
        "es": "¡Hola, ¿cómo estás? Encantado de conocerte.",
        "fr": "Bonjour, comment allez-vous? Ravi de vous rencontrer.",
        "de": "Hallo, wie geht es dir? Schön dich kennenzulernen.",
        "it": "Ciao, come stai? Piacere di conoscerti.",
        // Portuguese: seeds now come from `BrazilianPortuguesePack` (pt-BR
        // domain-specific text, including diacritics, R$ currency, dd/mm/aaaa
        // dates, and pan-Brazilian lexicon) and `PortuguesePack` (short
        // pan-Lusophone fallback). The pack lookup in `getLanguagePrompt`
        // runs first, so no "pt" entry is needed here.
        "ru": "Здравствуйте, как ваши дела? Приятно познакомиться.",
        "pl": "Cześć, jak się masz? Miło cię poznać.",
        "nl": "Hallo, hoe gaat het? Aangenaam kennis te maken.",
        "tr": "Merhaba, nasılsın? Tanıştığımıza memnun oldum.",
        
        // Middle Eastern Languages
        "ar": "مرحباً، كيف حالك؟ سعيد بلقائك.",
        "fa": "سلام، حال شما چطور است؟ از آشنایی با شما خوشوقتم.",
        "he": ",שלום, מה שלומך? נעים להכיר",
        
        // South Asian Languages
        "ta": "வணக்கம், எப்படி இருக்கிறீர்கள்? உங்களை சந்தித்ததில் மகிழ்ச்சி.",
        "te": "నమస్కారం, ఎలా ఉన్నారు? కలవడం చాలా సంతోషం.",
        "ml": "നമസ്കാരം, സുഖമാണോ? കണ്ടതിൽ സന്തോഷം.",
        "kn": "ನಮಸ್ಕಾರ, ಹೇಗಿದ್ದೀರಾ? ನಿಮ್ಮನ್ನು ಭೇಟಿಯಾಗಿ ಸಂತೋಷವಾಗಿದೆ.",
        "ur": "السلام علیکم، کیسے ہیں آپ؟ آپ سے مل کر خوشی ہوئی۔",
        
        // Default prompt for unsupported languages
        "default": ""
    ]
    
    init() {
        loadCustomPrompts()
        updateTranscriptionPrompt()
        
        // Setup notification observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLanguageChange),
            name: .languageDidChange,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleLanguageChange() {
        updateTranscriptionPrompt()
    }
    
    private func loadCustomPrompts() {
        if let savedPrompts = UserDefaults.standard.dictionary(forKey: customPromptsKey) as? [String: String] {
            customPrompts = savedPrompts
        }
    }
    
    private func saveCustomPrompts() {
        UserDefaults.standard.set(customPrompts, forKey: customPromptsKey)
        UserDefaults.standard.synchronize() // Force immediate synchronization
    }
    
    func updateTranscriptionPrompt() {
        // Resolve via LanguageResolver so the "default" sentinel expands
        // through Settings → Default language.
        let selectedLanguage = LanguageResolver.effectiveSTTCode(fallback: "en")
        
        // Get the prompt for the selected language (custom if available, otherwise default)
        let basePrompt = getLanguagePrompt(for: selectedLanguage)
        let prompt = basePrompt.isEmpty ? "" : basePrompt
        
        transcriptionPrompt = prompt
        UserDefaults.standard.set(prompt, forKey: "TranscriptionPrompt")
        UserDefaults.standard.synchronize() // Force immediate synchronization
        
        // Notify that the prompt has changed
        NotificationCenter.default.post(name: .promptDidChange, object: nil)
    }
    
    func getLanguagePrompt(for language: String) -> String {
        // First check if there's a custom prompt for this language
        if let customPrompt = customPrompts[language], !customPrompt.isEmpty {
            return customPrompt
        }

        // Pack-aware lookup: ask the locale pack for a domain-specific seed,
        // falling back to the pack's "default" seed when the requested domain
        // is unknown to the pack. Only after the pack has had a turn do we
        // fall through to the legacy `languagePrompts` table.
        let pack = LocalePackRegistry.pack(for: language)
        let domain = UserDefaults.standard
            .string(forKey: WhisperPrompt.domainKey)
            .flatMap(WhisperPromptDomain.init(rawValue:)) ?? .general
        let domainKey = domain == .general ? "default" : domain.rawValue
        if let seed = pack?.whisperPromptSeeds[domainKey], !seed.isEmpty {
            return seed
        }
        if domain != .general, let fallbackSeed = pack?.whisperPromptSeeds["default"], !fallbackSeed.isEmpty {
            return fallbackSeed
        }

        // Otherwise return the default prompt, with safe fallback
        return languagePrompts[language] ?? languagePrompts["default"] ?? ""
    }

    func setCustomPrompt(_ prompt: String, for language: String) {
        customPrompts[language] = prompt
        saveCustomPrompts()
        updateTranscriptionPrompt()
        
        // Force update the UI
        objectWillChange.send()
    }
}

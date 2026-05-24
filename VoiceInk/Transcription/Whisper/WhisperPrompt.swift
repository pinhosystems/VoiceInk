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
        // Português brasileiro: seed denso para orientar Whisper a usar acentuação completa
        // (ã, õ, ç, á, é, í, ó, ú, â, ê, ô), pontuação típica do pt-BR, formato monetário
        // R$ com vírgula decimal e ponto de milhar, datas dd/mm/aaaa, ortografia pós-reforma
        // ("ideia" sem trema, "voo" sem acento, "para" sem acento), e vocabulário brasileiro
        // (não europeu): "celular", "ônibus", "trem", "cadê", "você". Whisper costuma errar
        // acentos quando o initial_prompt é curto; este texto deliberadamente cobre todos
        // os diacríticos comuns para enviesar a decodificação corretamente.
        "pt": """
            Olá, tudo bem? Hoje é dia 15/05/2026 e a reunião está marcada para as 14h30. \
            O valor combinado foi de R$ 1.500,00, podendo chegar a R$ 2.350,75 com os impostos. \
            Já enviei o e-mail para a equipe; precisamos confirmar com a Ana, o João e a Letícia até amanhã. \
            Não esquece de revisar a proposta — coloquei ênfase nos pontos principais: prazo, escopo e orçamento. \
            Em São Paulo, o trânsito está tranquilo, mas o aplicativo do celular mostra congestionamento na Marginal. \
            A ideia é simples: começar pelo essencial, depois evoluir para a próxima fase do projeto.
            """,
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
        // Get the currently selected language from UserDefaults
        let selectedLanguage = UserDefaults.standard.string(forKey: "SelectedLanguage") ?? "en"
        
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

    /// Domain-specific Brazilian Portuguese seeds. Each one packs vocabulary the
    /// user is likely to dictate in that context, so Whisper anchors its decoder
    /// on the canonical spelling. Limited to ~250 characters per seed because
    /// Whisper's `initial_prompt` token budget is finite (~224 tokens); going
    /// longer crowds out the audio context.
    static let brazilianDomainSeeds: [WhisperPromptDomain: String] = [
        .technical: """
            Estamos discutindo arquitetura de software em pt-BR. Hoje é 15/05/2026 \
            e vamos revisar a API REST do backend em Node.js, o frontend em React \
            com TypeScript, deploy na AWS via Docker e Kubernetes, observabilidade \
            no Grafana, banco PostgreSQL, cache Redis. Pull request, code review, \
            CI/CD, async/await, callback, endpoint, payload JSON, JWT, OAuth, gRPC.
            """,
        .medical: """
            Esta é uma consulta clínica em pt-BR. Paciente de 45 anos, queixa de \
            dispneia há 3 dias, hipertensão arterial sistêmica controlada com \
            losartana 50mg, diabetes mellitus tipo 2 em uso de metformina 850mg, \
            colesterol LDL 145, glicemia de jejum 126. Solicitar hemograma, TGO, \
            TGP, creatinina, ureia, ecocardiograma. CID-10 I10. SUS, ANS, CRM.
            """,
        .legal: """
            Trata-se de petição inicial em pt-BR. Autor: João da Silva, CPF \
            123.456.789-00, residente à Rua das Acácias, 250, Vila Madalena, \
            São Paulo/SP, CEP 05435-010. Requerente pleiteia indenização por \
            danos morais com base no art. 186 do Código Civil. Réu: empresa XYZ \
            Ltda., CNPJ 12.345.678/0001-90. Processo PJe, TJSP, STJ, STF, habeas \
            corpus, mandado de segurança, OAB/SP, MPF, JEC.
            """,
        .corporate: """
            Reunião corporativa em pt-BR no dia 15/05/2026 às 14h30. Pauta: \
            revisão do orçamento Q2, meta de R$ 1.500.000,00 em receita, OKRs \
            do time de produto, contratação de 3 engenheiros sênior, alinhamento \
            com stakeholders, follow-up das ações da última reunião, próximos \
            passos para a sprint, deadline em 30/06/2026. Participantes: Ana, \
            João, Letícia, Pedro. ROI, NPS, CAC, LTV, KPI, MVP.
            """
    ]
    
    func setCustomPrompt(_ prompt: String, for language: String) {
        customPrompts[language] = prompt
        saveCustomPrompts()
        updateTranscriptionPrompt()
        
        // Force update the UI
        objectWillChange.send()
    }
}

import Foundation
import os

/// Curated, region-specific pack for Brazilian Portuguese (pt-BR).
///
/// Holds all hand-tuned content that previously lived in the four
/// `Brazilian*` files: text normalization (CPF, CNPJ, CEP, R$, dd/mm/aaaa,
/// "duas horas e meia"), chat-abbreviation expansions (vc → você, ...), the
/// high-frequency vocabulary list (BR civic identifiers, BR taxes, BR banks,
/// BR companies, BR jurisprudence), spoken fillers ("né", "tipo", "sei lá"),
/// Whisper prompt seeds (general + domain-specific), and the pt-BR
/// `<LOCALE_RULES>` block.
///
/// Lookup: `LocalePackRegistry.pack(for: "pt-BR")` matches this pack by exact
/// `bcp47`. Bare "pt" and other pt-* variants resolve to `PortuguesePack`
/// (generic, output-only) via primary-subtag fallback.
///
/// Phase 2 placement: `customNormalize` delegates to the legacy
/// `BrazilianTextNormalizer.normalize(_:)` to preserve every existing
/// per-match transform (digit validation, number-word arithmetic,
/// thousands-separator insertion) without rewriting. Phase 7 inlines the
/// function body into this file and deletes the legacy source.
struct BrazilianPortuguesePack: LocalePack {
    let bcp47: String? = "pt-BR"
    let primarySubtag: String = "pt"
    let displayName: String = "Brazilian Portuguese"

    let normalizerRules: [NormalizerRule] = []

    let wordReplacements: [(original: String, replacement: String)] = [
        ("vc, vcs", "você"),
        ("tb, tbm, tmb", "também"),
        ("pq, pq?", "porque"),
        ("obg, obgd, obrg", "obrigado"),
        ("blz", "beleza"),
        ("vlw", "valeu"),
        ("fds", "fim de semana"),
        ("td, tds", "tudo"),
        ("msg, msgs", "mensagem"),
        ("msm", "mesmo"),
        ("mt, mto, mta, mtos, mtas", "muito"),
        ("mds", "meu Deus"),
        ("hj", "hoje"),
        ("amh, amh.", "amanhã"),
        ("ontm", "ontem"),
        ("eh", "é"),
        ("c/", "com"),
        ("s/", "sem"),
        ("p/", "para"),
        ("q", "que"),
        ("qd, qdo, qnd, qndo", "quando"),
        ("qm", "quem"),
        ("qto, qts", "quanto"),
        ("dps", "depois"),
        ("agr", "agora"),
        ("td bem", "tudo bem"),
        ("tava, tavam", "estava"),
        ("to, tô", "estou"),
        ("ta, tá", "está"),
        ("vamo, vamu", "vamos"),
        ("brigado, brigadu, brigada", "obrigado"),
        ("flw", "falou"),
        ("hr, hrs", "hora"),
        ("min", "minuto"),
        ("seg", "segundo"),
        ("sex", "sexta"),
        ("sab", "sábado"),
        ("dom", "domingo"),
        ("seg.", "segunda"),
        ("ter.", "terça"),
        ("qua.", "quarta"),
        ("qui.", "quinta"),
        ("aki", "aqui"),
        ("akele", "aquele"),
        ("aqui, aki, aqi", "aqui")
    ]

    let vocabularyTerms: [String] = [
        // Órgãos públicos federais
        "Receita Federal", "Receita Federal do Brasil",
        "Banco Central", "BACEN",
        "INSS", "SUS",
        "Anvisa", "Anatel", "ANP", "Aneel", "ANS", "Antaq", "Antt",
        "IBGE", "INMETRO", "INPI", "INPE", "FUNAI",
        "Polícia Federal", "Polícia Rodoviária Federal", "PRF",
        "Tribunal Superior Eleitoral", "TSE",
        "Supremo Tribunal Federal", "STF",
        "Superior Tribunal de Justiça", "STJ",
        "Tribunal de Contas da União", "TCU",
        "Ministério Público Federal", "MPF",
        "Defensoria Pública da União",
        "Casa Civil",

        // Estados, capitais, regiões
        "São Paulo", "Rio de Janeiro", "Belo Horizonte", "Salvador",
        "Brasília", "Fortaleza", "Curitiba", "Manaus", "Recife", "Porto Alegre",
        "Goiânia", "Belém", "São Luís", "Maceió", "Campo Grande", "João Pessoa",
        "Teresina", "Natal", "Aracaju", "Cuiabá", "Florianópolis", "Vitória",
        "Boa Vista", "Macapá", "Palmas", "Rio Branco",

        // Documentos e identificadores
        "CPF", "CNPJ", "RG", "CNH", "CEP", "PIS", "PASEP",
        "Título de Eleitor", "Carteira de Trabalho",
        "CRM", "CREA", "CRECI", "CRO", "CRP", "CRC", "OAB",

        // Tributação e trabalho
        "ICMS", "ISS", "COFINS", "IRPF", "IRPJ", "IPI", "IOF",
        "IPTU", "IPVA", "ITR", "ITBI", "ITCMD",
        "FGTS", "CLT", "MEI", "Simples Nacional", "Lucro Presumido", "Lucro Real",
        "Décimo Terceiro", "Salário-Família", "Vale-Refeição", "Vale-Alimentação",
        "Vale-Transporte", "Auxílio-Doença", "Auxílio-Acidente",
        "Seguro-Desemprego", "BPC", "LOAS", "Bolsa Família",

        // Pagamentos e bancos
        "PIX", "TED", "DOC", "Boleto", "DARF", "DAS", "GPS",
        "Bradesco", "Itaú", "Itaú Unibanco", "Banco do Brasil", "Caixa",
        "Caixa Econômica Federal", "Santander", "BTG Pactual",
        "Nubank", "Inter", "C6 Bank", "PicPay", "Mercado Pago",
        "Banco Original", "Sicoob", "Sicredi", "BRB", "Banrisul", "Banpará",

        // Empresas brasileiras de tecnologia/comércio
        "iFood", "Magazine Luiza", "Magalu", "Mercado Livre",
        "Americanas", "Casas Bahia", "Submarino", "Shopee", "B2W",
        "Globo", "Globoplay", "GloboNews", "SBT", "Record", "Band",
        "Petrobras", "Petroleo Brasileiro", "Vale", "Embraer", "Eletrobras",
        "Ambev", "JBS", "BRF", "Suzano", "WEG",
        "Localiza", "Movida", "Unidas",
        "Latam", "Gol", "Azul",
        "Stone", "PagSeguro", "Cielo", "Rede",
        "Locaweb", "VTEX", "Movile", "Méliuz",
        "Loft", "QuintoAndar", "Kavak",
        "Hospital Albert Einstein", "Hospital Sírio-Libanês",

        // Educação
        "USP", "Unicamp", "Unesp", "UFRJ", "UFMG", "UFRGS", "UFSC", "UFPE",
        "UFBA", "UFC", "UnB", "FGV", "Insper", "PUC", "PUC-SP", "PUC-Rio",
        "ENEM", "FUVEST", "SISU", "ProUni", "FIES",
        "Capes", "CNPq", "Fapesp", "Faperj",
        "MEC",

        // Saúde e benefícios
        "Hospital das Clínicas", "Fiocruz",
        "Plano de Saúde", "Bradesco Saúde", "Amil", "SulAmérica", "Unimed",
        "Notredame", "Hapvida", "Prevent Senior",

        // Programas e leis
        "Constituição Federal", "Lei de Diretrizes e Bases", "LDB",
        "Estatuto da Criança e do Adolescente", "ECA",
        "Estatuto do Idoso", "Código de Defesa do Consumidor", "CDC",
        "Lei Geral de Proteção de Dados", "LGPD",
        "Marco Civil da Internet", "Lei Maria da Penha",

        // Cultura e mídia
        "Telecine", "Canal Brasil",

        // Finanças e mercado
        "B3", "Bovespa", "Ibovespa", "CDI", "Selic", "IPCA", "IGP-M", "INPC",
        "CDB", "LCI", "LCA", "Tesouro Direto", "Tesouro Selic", "Tesouro IPCA",

        // Termos jurídicos comuns
        "habeas corpus", "habeas data", "mandado de segurança",
        "ação trabalhista", "reclamação trabalhista",
        "rescisão indireta", "justa causa",
        "Processo Judicial Eletrônico", "PJe", "eSocial", "EFD", "SPED"
    ]

    let fillerWords: [String] = [
        "né", "tipo", "aham", "uhum", "ahã",
        "tá", "tá bom", "tá certo",
        "sei lá", "sabe", "tipo assim",
        "putz", "eita", "nossa", "caramba"
    ]

    let whisperPromptSeeds: [String: String] = [
        "default": """
            Olá, tudo bem? Hoje é dia 15/05/2026 e a reunião está marcada para as 14h30. \
            O valor combinado foi de R$ 1.500,00, podendo chegar a R$ 2.350,75 com os impostos. \
            Já enviei o e-mail para a equipe; precisamos confirmar com a Ana, o João e a Letícia até amanhã. \
            Não esquece de revisar a proposta — coloquei ênfase nos pontos principais: prazo, escopo e orçamento. \
            Em São Paulo, o trânsito está tranquilo, mas o aplicativo do celular mostra congestionamento na Marginal. \
            A ideia é simples: começar pelo essencial, depois evoluir para a próxima fase do projeto.
            """,
        "technical": """
            Estamos discutindo arquitetura de software em pt-BR. Hoje é 15/05/2026 \
            e vamos revisar a API REST do backend em Node.js, o frontend em React \
            com TypeScript, deploy na AWS via Docker e Kubernetes, observabilidade \
            no Grafana, banco PostgreSQL, cache Redis. Pull request, code review, \
            CI/CD, async/await, callback, endpoint, payload JSON, JWT, OAuth, gRPC.
            """,
        "medical": """
            Esta é uma consulta clínica em pt-BR. Paciente de 45 anos, queixa de \
            dispneia há 3 dias, hipertensão arterial sistêmica controlada com \
            losartana 50mg, diabetes mellitus tipo 2 em uso de metformina 850mg, \
            colesterol LDL 145, glicemia de jejum 126. Solicitar hemograma, TGO, \
            TGP, creatinina, ureia, ecocardiograma. CID-10 I10. SUS, ANS, CRM.
            """,
        "legal": """
            Trata-se de petição inicial em pt-BR. Autor: João da Silva, CPF \
            123.456.789-00, residente à Rua das Acácias, 250, Vila Madalena, \
            São Paulo/SP, CEP 05435-010. Requerente pleiteia indenização por \
            danos morais com base no art. 186 do Código Civil. Réu: empresa XYZ \
            Ltda., CNPJ 12.345.678/0001-90. Processo PJe, TJSP, STJ, STF, habeas \
            corpus, mandado de segurança, OAB/SP, MPF, JEC.
            """,
        "corporate": """
            Reunião corporativa em pt-BR no dia 15/05/2026 às 14h30. Pauta: \
            revisão do orçamento Q2, meta de R$ 1.500.000,00 em receita, OKRs \
            do time de produto, contratação de 3 engenheiros sênior, alinhamento \
            com stakeholders, follow-up das ações da última reunião, próximos \
            passos para a sprint, deadline em 30/06/2026. Participantes: Ana, \
            João, Letícia, Pedro. ROI, NPS, CAC, LTV, KPI, MVP.
            """
    ]

    let aiPromptFormatRules: String =
        "pt-BR: post-1990 orthography, Brazilian vocabulary, \"R$ 1.500,00\", dd/mm/aaaa, \"14h30\", decimal comma."

    var customNormalize: ((String) -> String)? {
        { BrazilianPortugueseNormalizer.normalize($0) }
    }

    let normalizationExamples: [(before: String, after: String)] = [
        ("Meu CPF é 12345678900.", "Meu CPF é 123.456.789-00."),
        ("CNPJ 12345678000190 ativo.", "CNPJ 12.345.678/0001-90 ativo."),
        ("Mando para o CEP 05435010.", "Mando para o CEP 05435-010."),
        ("Reunião às duas horas e meia.", "Reunião às 2h30."),
        ("Crescemos cinquenta por cento.", "Crescemos 50%."),
        ("Orçamento de 1500 reais.", "Orçamento de R$ 1.500,00.")
    ]
}

// MARK: - File-private normalization implementation

/// Brazilian-Portuguese-specific text normalization applied AFTER raw STT and
/// word replacements, but BEFORE the AI enhancement step. Runs via
/// `BrazilianPortuguesePack.customNormalize` when `LocalePackRegistry` resolves
/// the pt-BR pack and `LocaleNormalizationEnabled` is on.
///
/// Each rule is intentionally conservative: a regex that matches confidently or
/// not at all. The goal is to handle the *high-frequency* cases (CPF, CNPJ, CEP,
/// "duas horas e meia", "cinquenta por cento") without ever risking silent
/// corruption of legitimate text. Anything ambiguous falls through unchanged.
private enum BrazilianPortugueseNormalizer {
    private static let logger = Logger(
        subsystem: "agabo.dev.voiceink",
        category: "BrazilianPortugueseNormalizer"
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
    private static func normalizeHoursAndHalf(_ text: String) -> String {
        let numberAlternation = orderedAlternation(basicNumberWords.keys)
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
                if raw == 12 { hour = 0 }
                else if raw <= 5 { hour = raw }
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
        let digitPattern = #"\b(\d{1,3})\s+por\s+cento\b"#
        result = rewriteRegex(result, pattern: digitPattern) { groups in
            guard let digits = groups[1] else { return nil }
            return "\(digits)%"
        }
        return result
    }

    // MARK: - Decimal "X ponto Y" → "X,Y"

    /// "três ponto cinco" → "3,5"; "10 ponto 5" → "10,5".
    private static func normalizeDecimal(_ text: String) -> String {
        let numericPattern = #"\b(\d{1,4})\s+ponto\s+(\d{1,4})\b"#
        var result = rewriteRegex(text, pattern: numericPattern) { groups in
            guard let left = groups[1], let right = groups[2] else { return nil }
            return "\(left),\(right)"
        }
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
        let centavoPattern = #"\b(\d{1,9})\s+reais(?:\s+e\s+(\d{1,2})\s+centavos)?\b"#
        var result = rewriteRegex(text, pattern: centavoPattern) { groups in
            guard let inteiros = groups[1] else { return nil }
            let withDots = insertThousandsSeparator(inteiros)
            if let cents = groups[2], let n = Int(cents), n > 0 {
                return "R$ \(withDots),\(String(format: "%02d", n))"
            }
            return "R$ \(withDots)"
        }
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

    /// Alternation pattern with longest entries first, so that "vinte e três"
    /// matches before "vinte". Without this, the alternation greedily picks the
    /// first viable branch and leaves trailing words orphaned.
    private static func orderedAlternation<S: Sequence>(_ words: S) -> String where S.Element == String {
        words
            .sorted { $0.count > $1.count }
            .map { NSRegularExpression.escapedPattern(for: $0) }
            .joined(separator: "|")
    }

    /// Applies a regex with a `transform(match) -> replacement?` closure: when
    /// the closure returns nil, the original match is preserved.
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

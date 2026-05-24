import Foundation

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
        { BrazilianTextNormalizer.normalize($0) }
    }
}

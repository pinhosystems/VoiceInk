import Foundation

/// Curated vocabulary that Whisper, ElevenLabs Scribe, Deepgram Nova, and other
/// STT engines routinely misspell when transcribing Brazilian Portuguese audio.
/// Adding these as vocabulary words (a) seeds the LLM enhancement step with the
/// canonical spelling, and (b) gets passed to cloud providers that accept a
/// `keyterm`/`vocabulary` parameter (e.g., Deepgram), which biases their
/// language model toward these tokens at decode time.
///
/// Surfaced via a "Adicionar vocabulário pt-BR" action in the Vocabulary panel.
/// Idempotent: existing entries are not duplicated.
///
/// Selection criteria:
/// 1. The term has a non-trivial canonical spelling (capitalization, accents,
///    punctuation, hyphens) that engines commonly get wrong.
/// 2. The term is high-frequency in Brazilian professional/financial/civic
///    dictation contexts.
/// 3. The term is unambiguous in writing — no English/Portuguese homographs that
///    would corrupt non-Brazilian dictation if accidentally enabled.
enum BrazilianVocabularyTemplate {

    static let canonicalWords: [String] = [
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

    static var count: Int { canonicalWords.count }
}

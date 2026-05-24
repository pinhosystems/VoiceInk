import Foundation

/// Russian pack covering ru, ru-RU. Russia and Russian-speaking CIS countries.
/// Cyrillic script, decimal comma, ruble currency, patronymic name conventions.
struct RussianPack: LocalePack {
    let primarySubtag: String = "ru"
    let displayName: String = "Russian"

    // MARK: - Filler Words

    let fillerWords: [String] = [
        "э", "эм", "ну", "вот", "как бы",
        "типа", "короче", "в общем", "значит", "так сказать",
        "собственно", "грубо говоря", "слушай", "смотри",
        "понимаешь", "знаешь", "то есть", "допустим",
        "скажем так", "ладно", "блин"
    ]

    // MARK: - Word Replacements

    let wordReplacements: [(original: String, replacement: String)] = [
        ("спс, спасиб", "спасибо"),
        ("пжл, пжлст", "пожалуйста"),
        ("инфо", "информация"),
        ("комп", "компьютер"),
        ("прога", "программа"),
        ("норм", "нормально"),
        ("инет", "интернет"),
        ("др", "день рождения"),
        ("имхо", "по моему мнению"),
        ("кмк", "как мне кажется"),
        ("лс", "личное сообщение"),
        ("тел", "телефон"),
        ("мб", "может быть"),
        ("хз", "не знаю"),
        ("чел", "человек")
    ]

    // MARK: - Vocabulary Terms

    let vocabularyTerms: [String] = [
        // Government / institutions
        "Государственная Дума", "Совет Федерации",
        "Конституционный Суд", "Верховный Суд",
        "Правительство", "Президент",
        "Министерство финансов", "ФНС",
        "Центральный банк", "Банк России",
        "Пенсионный фонд", "ФСБ", "МВД", "МИД",
        "Роспотребнадзор", "Росреестр", "Роскомнадзор",

        // Companies
        "Газпром", "Роснефть", "Сбербанк", "ВТБ",
        "Яндекс", "Mail.ru", "Тинькофф", "Озон",
        "Wildberries", "Лукойл", "Ростелеком",
        "Аэрофлот", "РЖД", "МТС", "Мегафон", "Билайн",

        // Education
        "МГУ", "СПбГУ", "МФТИ", "МГТУ имени Баумана",
        "НИУ ВШЭ", "ИТМО", "Сколтех",
        "ЕГЭ", "ОГЭ", "аспирантура", "диссертация",

        // Documents
        "ИНН", "СНИЛС", "ОГРН", "КПП",
        "паспорт", "загранпаспорт", "водительские права",
        "свидетельство о рождении", "трудовая книжка",

        // Finance
        "рубль", "копейка", "НДФЛ", "НДС",
        "МРОТ", "ПФР", "ФСС",
        "ММВБ", "индекс РТС", "Мосбиржа",

        // Geography
        "Москва", "Санкт-Петербург", "Новосибирск",
        "Екатеринбург", "Казань", "Нижний Новгород",
        "Красноярск", "Владивосток", "Сочи"
    ]

    // MARK: - Normalizer Rules

    let normalizerRules: [NormalizerRule] = [
        // Russian phone: +7 (XXX) XXX-XX-XX
        NormalizerRule(
            pattern: #"(?<!\d)\+?[78][\s.-]?\(?(\d{3})\)?[\s.-]?(\d{3})[\s.-]?(\d{2})[\s.-]?(\d{2})(?!\d)"#,
            options: [],
            replacement: "+7 ($1) $2-$3-$4",
            description: "Format Russian phone: +7 (XXX) XXX-XX-XX"
        ),
        // ИНН (12 digits for individuals, 10 for legal entities)
        NormalizerRule(
            pattern: #"(?i)(?:ИНН)\s*[:\s]*(\d{10,12})\b"#,
            options: [.caseInsensitive],
            replacement: "ИНН $1",
            description: "Format ИНН number"
        ),
        // СНИЛС: XXX-XXX-XXX XX
        NormalizerRule(
            pattern: #"(?<!\d)(\d{3})[\s.-]?(\d{3})[\s.-]?(\d{3})[\s.-]?(\d{2})(?!\d)"#,
            options: [],
            replacement: "$1-$2-$3 $4",
            description: "Format СНИЛС: XXX-XXX-XXX XX"
        )
    ]

    // MARK: - Normalization Examples

    let normalizationExamples: [(before: String, after: String)] = [
        (before: "+79161234567", after: "+7 (916) 123-45-67"),
        (before: "ИНН 1234567890", after: "ИНН 1234567890"),
        (before: "12345678901", after: "123-456-789 01")
    ]

    // MARK: - Whisper Prompt Seeds

    let whisperPromptSeeds: [String: String] = [
        "default": "Здравствуйте, как у вас дела? Сегодня мы обсудим следующий этап проекта.",
        "technical": "Команда инженеров проверила развёртывание Kubernetes, вызовы API и задержку базы данных PostgreSQL."
    ]

    // MARK: - AI Prompt Format Rules

    let aiPromptFormatRules: String = """
    ru: standard Russian orthography. Decimal comma, space as thousands \
    separator ("1 500,00 ₽"). Currency: ₽ or "руб." after amount. Dates: \
    dd.mm.yyyy. Time: 24h with colon (14:30). Lowercase month/weekday names. \
    Russian quotation marks: «ёлочки» outer, „лапки" inner. Preserve ё where \
    it disambiguates. Patronymics in formal address (Иван Иванович).
    """
}

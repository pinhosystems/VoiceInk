import Foundation

/// Turkish pack covering tr, tr-TR. Turkey's 85M+ speakers plus Turkish
/// diaspora. Handles Turkish-specific characters (ç, ğ, ı, İ, ö, ş, ü),
/// agglutinative word forms, and Turkish formatting conventions.
struct TurkishPack: LocalePack {
    let primarySubtag: String = "tr"
    let displayName: String = "Turkish"

    // MARK: - Filler Words

    let fillerWords: [String] = [
        "şey", "yani", "hani", "işte", "aslında",
        "mesela", "bir nevi", "açıkçası", "nasıl diyeyim",
        "şöyle", "böyle", "falan", "filan", "ya",
        "e", "ee", "aa", "hmm", "tamam",
        "bak", "dinle", "gel"
    ]

    // MARK: - Word Replacements

    let wordReplacements: [(original: String, replacement: String)] = [
        ("slm", "selam"),
        ("mrb", "merhaba"),
        ("nbr", "ne haber"),
        ("tşk, teşk", "teşekkürler"),
        ("özr", "özür"),
        ("tmm", "tamam"),
        ("peki", "peki"),
        ("hyr", "hayır"),
        ("evt", "evet"),
        ("grş", "görüşürüz"),
        ("hg", "hoş geldiniz"),
        ("hb", "hoş bulduk"),
        ("iyi akşmlar", "iyi akşamlar"),
        ("tel", "telefon"),
        ("msj", "mesaj"),
        ("blg", "bilgi"),
        ("öd", "ödeme"),
        ("sgrt", "sigorta")
    ]

    // MARK: - Vocabulary Terms

    let vocabularyTerms: [String] = [
        // Government / institutions
        "TBMM", "Türkiye Büyük Millet Meclisi",
        "Cumhurbaşkanlığı", "Anayasa Mahkemesi",
        "Yargıtay", "Danıştay", "Sayıştay",
        "Gelir İdaresi Başkanlığı", "SGK",
        "TCMB", "Türkiye Cumhuriyet Merkez Bankası",
        "SPK", "BDDK", "TÜİK",
        "Emniyet Genel Müdürlüğü", "Jandarma",
        "MEB", "YÖK", "ÖSYM",

        // Companies / brands
        "Türk Telekom", "Turkcell", "Vodafone",
        "THY", "Türk Hava Yolları", "Pegasus",
        "İş Bankası", "Garanti BBVA", "Akbank", "Yapı Kredi",
        "Koç Holding", "Sabancı Holding", "Arçelik", "Vestel",
        "Trendyol", "Hepsiburada", "Getir", "BİM", "A101",

        // Education
        "Boğaziçi Üniversitesi", "ODTÜ", "İTÜ",
        "Bilkent", "Koç Üniversitesi", "Sabancı Üniversitesi",
        "YKS", "LGS", "ALES", "KPSS", "TUS", "DGS",

        // Documents
        "T.C. kimlik numarası", "vergi numarası",
        "ehliyet", "pasaport", "ikametgâh",
        "nüfus cüzdanı", "SGK numarası",

        // Finance
        "BIST", "Borsa İstanbul",
        "TL", "Türk Lirası", "KDV",
        "gelir vergisi", "kurumlar vergisi",
        "e-Devlet", "e-Fatura", "e-Arşiv",

        // Geography
        "İstanbul", "Ankara", "İzmir", "Antalya",
        "Bursa", "Adana", "Gaziantep", "Konya",
        "Trabzon", "Diyarbakır", "Eskişehir"
    ]

    // MARK: - Normalizer Rules

    let normalizerRules: [NormalizerRule] = [
        // Turkish phone: +90 (5XX) XXX XX XX (mobile)
        NormalizerRule(
            pattern: #"(?<!\d)\+?\s*90\s*\(?(\d{3})\)?\s*(\d{3})\s*(\d{2})\s*(\d{2})(?!\d)"#,
            options: [],
            replacement: "+90 ($1) $2 $3 $4",
            description: "Format Turkish phone: +90 (5XX) XXX XX XX"
        ),
        // T.C. Kimlik No: 11 digits
        NormalizerRule(
            pattern: #"(?i)(?:T\.?C\.?\s*(?:kimlik|no|numarası)?)\s*[:\s]*(\d{11})\b"#,
            options: [.caseInsensitive],
            replacement: "T.C. $1",
            description: "Format T.C. kimlik numarası"
        )
    ]

    // MARK: - Normalization Examples

    let normalizationExamples: [(before: String, after: String)] = [
        (before: "+905321234567", after: "+90 (532) 123 45 67"),
        (before: "TC 12345678901", after: "T.C. 12345678901")
    ]

    // MARK: - Whisper Prompt Seeds

    let whisperPromptSeeds: [String: String] = [
        "default": "Merhaba, nasılsınız? Bugün projenin bir sonraki aşamasını gözden geçireceğiz.",
        "technical": "Mühendislik ekibi Kubernetes dağıtımını, API çağrılarını ve PostgreSQL veritabanı gecikmesini inceledi."
    ]

    // MARK: - AI Prompt Format Rules

    let aiPromptFormatRules: String = """
    tr: standard Turkish orthography with dotted İ/i and dotless I/ı \
    distinction. Decimal comma, period as thousands separator ("1.500,00 ₺"). \
    Currency: ₺ or "TL" after amount. Dates: dd.mm.yyyy. Time: 24h with colon \
    (14:30) or "saat 14.30". Turkish quotation marks: "..." or «...». \
    Preserve Turkish-specific characters: ç, ğ, ı, İ, ö, ş, ü. Lowercase \
    month and weekday names. Suffixes follow vowel harmony rules.
    """
}

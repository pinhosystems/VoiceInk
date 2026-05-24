import Foundation

/// Hindi pack covering hi, hi-IN. India's primary language with 600M+ speakers.
/// Handles Devanagari script conventions, Hinglish code-switching (common in
/// tech/urban dictation), and Indian formatting (INR ₹, dd/mm/yyyy, lakhs/crores).
struct HindiPack: LocalePack {
    let bcp47: String? = "hi-IN"
    let primarySubtag: String = "hi"
    let displayName: String = "Hindi"

    // MARK: - Filler Words

    let fillerWords: [String] = [
        "अच्छा", "हाँ", "तो", "मतलब", "बस",
        "वो", "ये", "अरे", "देखो", "सुनो",
        "बोलो", "जैसे", "कुछ", "ना", "है ना",
        "समझे", "पता है", "क्या बोलें", "ठीक है",
        "actually", "basically", "like", "you know"
    ]

    // MARK: - Word Replacements

    let wordReplacements: [(original: String, replacement: String)] = [
        ("btw", "by the way"),
        ("msg", "message"),
        ("thx, thnx", "thanks"),
        ("pls, plz", "please"),
        ("govt", "government"),
        ("info", "information"),
        ("dept", "department"),
        ("approx", "approximately")
    ]

    // MARK: - Vocabulary Terms

    let vocabularyTerms: [String] = [
        // Government / institutions
        "लोकसभा", "राज्यसभा", "संसद", "सुप्रीम कोर्ट",
        "राष्ट्रपति", "प्रधानमंत्री", "मुख्यमंत्री",
        "आधार", "पैन कार्ड", "वोटर आईडी",
        "आयकर विभाग", "भारतीय रिजर्व बैंक", "RBI",
        "SEBI", "NITI Aayog", "CAG",
        "GST", "CGST", "SGST", "IGST",

        // Companies / brands
        "रिलायंस", "टाटा", "इंफोसिस", "विप्रो", "HCL",
        "बजाज", "महिंद्रा", "एयरटेल", "जियो",
        "फ्लिपकार्ट", "ज़ोमैटो", "स्विगी", "पेटीएम",
        "PhonePe", "CRED", "Zerodha", "Groww",

        // Education
        "IIT", "IIM", "AIIMS", "NIT", "ISRO",
        "JEE", "NEET", "UPSC", "SSC", "GATE",
        "दिल्ली विश्वविद्यालय", "JNU", "BHU",

        // Geography
        "दिल्ली", "मुंबई", "बेंगलुरु", "चेन्नई", "कोलकाता",
        "हैदराबाद", "पुणे", "अहमदाबाद", "जयपुर", "लखनऊ",
        "चंडीगढ़", "भोपाल", "पटना", "गुवाहाटी",

        // Finance
        "सेंसेक्स", "निफ्टी", "BSE", "NSE",
        "म्यूचुअल फंड", "SIP", "PPF", "EPF",
        "FD", "RD", "NPS", "LIC",
        "UPI", "NEFT", "RTGS", "IMPS",

        // Documents
        "आधार", "PAN", "DL", "पासपोर्ट",
        "राशन कार्ड", "जन्म प्रमाणपत्र",
        "ITR", "Form 16", "TDS"
    ]

    // MARK: - Normalizer Rules

    let normalizerRules: [NormalizerRule] = [
        // Aadhaar: 12 digits → groups of 4
        NormalizerRule(
            pattern: #"\b(\d{4})\s*(\d{4})\s*(\d{4})\b"#,
            options: [],
            replacement: "$1 $2 $3",
            description: "Format Aadhaar number as 4-4-4 groups"
        ),
        // PAN: ABCDE1234F format validation
        NormalizerRule(
            pattern: #"\b([A-Z]{5})(\d{4})([A-Z])\b"#,
            options: [],
            replacement: "$1$2$3",
            description: "Preserve PAN card format"
        ),
        // Phone: +91 followed by 10 digits
        NormalizerRule(
            pattern: #"(?<!\d)\+?\s*91[\s.-]*(\d{5})[\s.-]*(\d{5})(?!\d)"#,
            options: [],
            replacement: "+91 $1 $2",
            description: "Format Indian mobile number"
        ),
        // Pin code: 6 digits
        NormalizerRule(
            pattern: #"(?i)\b(pin\s*code|पिन\s*कोड)\s*[:\s]*(\d{6})\b"#,
            options: [.caseInsensitive],
            replacement: "$1 $2",
            description: "Format Indian PIN code"
        )
    ]

    // MARK: - Normalization Examples

    let normalizationExamples: [(before: String, after: String)] = [
        (before: "आधार 234567891234", after: "आधार 2345 6789 1234"),
        (before: "+919876543210", after: "+91 98765 43210"),
        (before: "pin code:110001", after: "pin code 110001")
    ]

    // MARK: - Whisper Prompt Seeds

    let whisperPromptSeeds: [String: String] = [
        "default": "नमस्ते, आप कैसे हैं? आज हम प्रोजेक्ट की अगली फेज पर चर्चा करेंगे।",
        "technical": "इंजीनियरिंग टीम ने Kubernetes डिप्लॉयमेंट, API कॉल्स और PostgreSQL डेटाबेस की लेटेंसी रिव्यू की।"
    ]

    // MARK: - AI Prompt Format Rules

    let aiPromptFormatRules: String = """
    hi: Hindi in Devanagari script. Preserve Hinglish code-switching where the \
    speaker naturally mixes Hindi and English (common in tech/urban contexts). \
    Indian number system: lakhs (1,00,000) and crores (1,00,00,000) with \
    Indian comma grouping. Currency: ₹ before amount (₹1,500). Dates: \
    dd/mm/yyyy. Time: 12h with AM/PM common, 24h in formal. Full stop (।) \
    for Devanagari sentences. When technical terms are spoken in English, \
    keep them in Latin script within the Hindi text.
    """
}

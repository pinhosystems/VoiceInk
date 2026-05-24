import Foundation

/// Arabic pack covering ar, ar-SA, ar-EG, ar-AE, ar-MA, etc. Modern Standard
/// Arabic (MSA / فصحى) as baseline with formatting conventions shared across
/// the Arab world. Region-specific packs (ar-EG for Egyptian dialect, ar-MA
/// for Darija) can ship later for colloquial-specific fillers and vocabulary.
struct ArabicPack: LocalePack {
    let primarySubtag: String = "ar"
    let displayName: String = "Arabic"

    // MARK: - Filler Words

    let fillerWords: [String] = [
        "يعني", "طيب", "آه", "إيه", "هممم",
        "يلا", "خلاص", "ماشي", "بس", "كذا",
        "والله", "إن شاء الله", "الله يعطيك العافية",
        "شوف", "أقصد", "بالضبط", "صح",
        "عادي", "أوكي", "تمام"
    ]

    // MARK: - Word Replacements

    let wordReplacements: [(original: String, replacement: String)] = [
        ("اوك", "حسنًا"),
        ("ثانكس", "شكرًا"),
        ("بليز", "من فضلك"),
        ("مسج", "رسالة"),
        ("لول", "مضحك"),
        ("اسف", "آسف"),
        ("ان شاء الله", "إن شاء الله"),
        ("جزاك الله خير", "جزاك الله خيرًا")
    ]

    // MARK: - Vocabulary Terms

    let vocabularyTerms: [String] = [
        // Pan-Arab institutions
        "جامعة الدول العربية", "مجلس التعاون الخليجي",
        "صندوق النقد العربي", "أوبك",

        // Saudi Arabia (largest market)
        "هيئة الزكاة والضريبة والجمارك",
        "وزارة الموارد البشرية", "التأمينات الاجتماعية",
        "الهيئة العامة للترفيه", "نيوم", "أرامكو",
        "صندوق الاستثمارات العامة", "رؤية 2030",
        "الهوية الوطنية", "أبشر", "توكلنا", "نفاذ",
        "المقيم", "مكتب العمل",

        // UAE
        "هيئة الطرق والمواصلات", "طيران الإمارات",
        "بنك أبوظبي الأول", "إعمار", "دبي مول",

        // Egypt
        "الأهرام", "الأزهر", "جامعة القاهرة",
        "البنك المركزي المصري", "الهيئة العامة للاستثمار",

        // Finance
        "ريال", "درهم", "جنيه", "دينار",
        "تداول", "سوق أبوظبي", "البورصة المصرية",
        "زكاة", "ضريبة القيمة المضافة",

        // Tech (Arabic equivalents)
        "تطبيق", "خادم", "قاعدة بيانات", "سحابة",
        "برمجة", "واجهة برمجية", "ذكاء اصطناعي",
        "تعلم آلي", "أمن سيبراني",

        // Education
        "جامعة الملك سعود", "جامعة الملك فهد",
        "الجامعة الأمريكية", "كاوست",
        "الثانوية العامة", "البكالوريوس", "الماجستير"
    ]

    // MARK: - Normalizer Rules

    let normalizerRules: [NormalizerRule] = [
        // Saudi phone: +966 5X XXX XXXX
        NormalizerRule(
            pattern: #"(?<!\d)\+?\s*966\s*(\d{2})\s*(\d{3})\s*(\d{4})(?!\d)"#,
            options: [],
            replacement: "+966 $1 $2 $3",
            description: "Format Saudi phone number"
        ),
        // Egyptian phone: +20 1X XXXX XXXX
        NormalizerRule(
            pattern: #"(?<!\d)\+?\s*20\s*(\d{2})\s*(\d{4})\s*(\d{4})(?!\d)"#,
            options: [],
            replacement: "+20 $1 $2 $3",
            description: "Format Egyptian phone number"
        ),
        // UAE phone: +971 5X XXX XXXX
        NormalizerRule(
            pattern: #"(?<!\d)\+?\s*971\s*(\d{2})\s*(\d{3})\s*(\d{4})(?!\d)"#,
            options: [],
            replacement: "+971 $1 $2 $3",
            description: "Format UAE phone number"
        )
    ]

    // MARK: - Normalization Examples

    let normalizationExamples: [(before: String, after: String)] = [
        (before: "+966501234567", after: "+966 50 123 4567"),
        (before: "+201012345678", after: "+20 10 1234 5678")
    ]

    // MARK: - Whisper Prompt Seeds

    let whisperPromptSeeds: [String: String] = [
        "default": "مرحبًا، كيف حالك؟ اليوم سنراجع المرحلة التالية من المشروع.",
        "technical": "فريق الهندسة راجع نشر Kubernetes واستدعاءات API وزمن استجابة قاعدة بيانات PostgreSQL."
    ]

    // MARK: - AI Prompt Format Rules

    let aiPromptFormatRules: String = """
    ar: Modern Standard Arabic (فصحى). Right-to-left script. Use Arabic-Indic \
    numerals (٠١٢٣٤٥٦٧٨٩) for inline Arabic text, Western Arabic numerals \
    (0123456789) for technical/code contexts. Dates: dd/mm/yyyy with Gregorian \
    calendar (Hijri in parentheses when relevant). Currency: symbol after amount \
    for SAR/AED/EGP ("1,500 ر.س" or "1,500 ج.م"). Decimal separator is period \
    in Gulf, comma in North Africa — prefer period for consistency. Arabic \
    comma (،) and semicolon (؛). Quotation marks: «» or "". Proper tashkeel \
    (diacritics) on ambiguous words only. Preserve hamza placement (إ أ ؤ ئ).
    """
}

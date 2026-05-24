import Foundation

/// Generic Italian pack covering it, it-IT, it-CH. Output-only Tier 1:
/// Whisper prompt seed in Italian plus a format-rules block tuned for the
/// standard Italian conventions. Swiss Italian (it-CH) uses the same number
/// formatting as Italian; currency is CHF rather than EUR for some
/// contexts, but Italian conventions otherwise apply.
struct ItalianPack: LocalePack {
    let primarySubtag: String = "it"
    let displayName: String = "Italian"

    let normalizerRules: [NormalizerRule] = []
    let wordReplacements: [(original: String, replacement: String)] = []
    let vocabularyTerms: [String] = []
    let fillerWords: [String] = []

    let whisperPromptSeeds: [String: String] = [
        "default": "Ciao, come stai? Oggi rivediamo la prossima fase del progetto.",
        "technical": "Il team di ingegneria ha esaminato il deployment Kubernetes, le chiamate API e la latenza del database PostgreSQL."
    ]

    let aiPromptFormatRules: String = """
    it: standard Italian orthography, decimal comma, period as thousands \
    separator ("1.500,00 €"), dd/mm/aaaa, 24h time with colon (14:30), \
    lowercase month and weekday names. Italian uses « » or " " for quotation \
    marks; apostrophes are common in contractions ("l'utente", "dell'API").
    """
}

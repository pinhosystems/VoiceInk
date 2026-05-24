import Foundation

/// Generic German pack covering de, de-DE, de-AT, de-CH, de-LI. Output-only
/// Tier 1: Whisper prompt seed in German plus a format-rules block tuned for
/// the standard German conventions used across DACH (Germany, Austria,
/// Switzerland). Swiss German uses the apostrophe as the thousands separator
/// ("1'500.00") — a curated de-CH pack can ship later for that variant.
struct GermanPack: LocalePack {
    let primarySubtag: String = "de"
    let displayName: String = "German"

    let normalizerRules: [NormalizerRule] = []
    let wordReplacements: [(original: String, replacement: String)] = []
    let vocabularyTerms: [String] = []
    let fillerWords: [String] = []

    let whisperPromptSeeds: [String: String] = [
        "default": "Hallo, wie geht es dir? Heute besprechen wir die nächste Phase des Projekts.",
        "technical": "Das Entwicklungsteam überprüfte die Kubernetes-Bereitstellung, die API-Aufrufe und die Latenz der PostgreSQL-Datenbank."
    ]

    let aiPromptFormatRules: String = """
    de: standard German orthography (post-1996 reform), decimal comma, period \
    as thousands separator ("1.500,00 €"), dd.mm.jjjj date format, 24h time \
    with colon (14:30), capitalised nouns, scharfes S "ß" where applicable \
    (Switzerland substitutes "ss"). Numbers below 13 typically spelled out \
    in formal prose. Use German quotation style: „opening" and "closing".
    """
}

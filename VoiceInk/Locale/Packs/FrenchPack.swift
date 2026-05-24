import Foundation

/// Generic French pack covering fr, fr-FR, fr-CA, fr-BE, fr-CH, etc.
/// Output-only Tier 1: Whisper prompt seed in French plus a metropolitan
/// French format-rules block. Quebec-specific currency formatting
/// (e.g. "1 500,00 $") and Belgian / Swiss conventions are close enough that
/// the metropolitan defaults still read correctly for those regions; a
/// curated fr-CA pack can ship later for precise treatment.
struct FrenchPack: LocalePack {
    let primarySubtag: String = "fr"
    let displayName: String = "French"

    let normalizerRules: [NormalizerRule] = []
    let wordReplacements: [(original: String, replacement: String)] = []
    let vocabularyTerms: [String] = []
    let fillerWords: [String] = []

    let whisperPromptSeeds: [String: String] = [
        "default": "Bonjour, comment allez-vous ? Aujourd'hui nous allons revoir la prochaine étape du projet.",
        "technical": "L'équipe d'ingénierie a passé en revue le déploiement Kubernetes, les appels d'API et la latence de la base de données PostgreSQL."
    ]

    let aiPromptFormatRules: String = """
    fr: standard French orthography, decimal comma, non-breaking space as \
    thousands separator and before currency symbol ("1 500,00 €"), \
    dd/mm/aaaa, 24h time with "h" separator (14h30), lowercase month and \
    weekday names. French typography requires a non-breaking space before \
    the two-part punctuation marks ":", ";", "!", "?" and inside «…» quotes.
    """
}

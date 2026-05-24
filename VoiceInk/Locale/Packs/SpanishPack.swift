import Foundation

/// Generic Spanish pack covering every es-* variant (es-ES, es-MX, es-AR,
/// es-CL, es-CO, etc.). Output-only: ships a Whisper prompt seed in Spanish
/// and a format-rules block tuned for the dominant peninsular conventions
/// (€ currency, decimal comma, dd/mm/aaaa). Region-specific currency and
/// number formatting (e.g. Mexican peso, period as decimal separator in
/// some financial contexts) would need a curated es-MX / es-AR / es-CL pack
/// shipped later with an explicit bcp47.
///
/// Input transforms (normalization, abbreviations, fillers, vocabulary) are
/// intentionally empty until they can be curated against real Spanish-language
/// transcription samples — guessing those would hurt accuracy more than help.
struct SpanishPack: LocalePack {
    let primarySubtag: String = "es"
    let displayName: String = "Spanish"

    let normalizerRules: [NormalizerRule] = []
    let wordReplacements: [(original: String, replacement: String)] = []
    let vocabularyTerms: [String] = []
    let fillerWords: [String] = []

    let whisperPromptSeeds: [String: String] = [
        "default": "Hola, ¿cómo estás? Hoy vamos a revisar la próxima fase del proyecto.",
        "technical": "El equipo de ingeniería revisó el despliegue en Kubernetes, las llamadas a la API y la latencia de la base de datos PostgreSQL."
    ]

    let aiPromptFormatRules: String = """
    es: standard Spanish orthography (RAE), decimal comma, "€ 1.500,00" or \
    "$1.500,00" depending on regional currency, dd/mm/aaaa, 24h time, \
    inverted opening punctuation (¿, ¡), and lowercase month/weekday names. \
    Use the Real Academia Española punctuation conventions: space before \
    quotation marks but not before colons.
    """
}

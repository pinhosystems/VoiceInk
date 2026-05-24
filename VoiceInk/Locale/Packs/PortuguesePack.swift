import Foundation

/// Generic, conservative pack for any Portuguese variant other than pt-BR.
///
/// Resolves via `LocalePackRegistry.pack(for:)`'s primary-subtag fallback for
/// "pt", "pt-PT", "pt-AO", "pt-MZ", "pt-CV", and any other pt-* code that
/// does not match a more specific `bcp47` pack. pt-BR has its own curated
/// pack (`BrazilianPortuguesePack`) and never lands here.
///
/// Ships output-only content by design (see Section 7.4 of
/// `docs/MULTILINGUAL_PLAN.md`): all curated input transforms in the codebase
/// today are BR-specific (R$, CPF, Brazilian fillers, BR civic vocabulary)
/// and would mislead non-BR users. The pack provides just enough LLM
/// guidance to keep European-Portuguese formatting consistent. Curated
/// pt-PT / PALOP packs can ship later with a region-specific `bcp47` and
/// will take precedence automatically.
struct PortuguesePack: LocalePack {
    let primarySubtag: String = "pt"
    let displayName: String = "Portuguese"

    let normalizerRules: [NormalizerRule] = []

    let wordReplacements: [(original: String, replacement: String)] = []

    let vocabularyTerms: [String] = []

    let fillerWords: [String] = []

    let whisperPromptSeeds: [String: String] = [
        "default": "Olá, como está? Hoje vamos rever a próxima fase do projeto."
    ]

    let aiPromptFormatRules: String = """
    pt-PT: European Portuguese, "€ 1.500,00".
    Other pt-* variants follow European Portuguese conventions unless otherwise indicated.
    """
}

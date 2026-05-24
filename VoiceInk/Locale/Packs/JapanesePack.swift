import Foundation

/// Generic Japanese pack. Output-only Tier 1: Whisper prompt seed in
/// Japanese plus a format-rules block covering the dominant Japanese
/// conventions. Japanese uses no spaces between words and applies its own
/// punctuation set (。、「」); LLM responses should preserve that style.
struct JapanesePack: LocalePack {
    let primarySubtag: String = "ja"
    let displayName: String = "Japanese"

    let normalizerRules: [NormalizerRule] = []
    let wordReplacements: [(original: String, replacement: String)] = []
    let vocabularyTerms: [String] = []
    let fillerWords: [String] = []

    let whisperPromptSeeds: [String: String] = [
        "default": "こんにちは、お元気ですか。今日はプロジェクトの次の段階を見直します。",
        "technical": "エンジニアリングチームはKubernetesのデプロイ、APIコール、PostgreSQLデータベースのレイテンシを確認しました。"
    ]

    let aiPromptFormatRules: String = """
    ja: standard Japanese conventions. Use full-width punctuation: \
    句点「。」, 読点「、」, 鉤括弧「」 for quotation marks. Currency: ¥ \
    or 円 with no decimal places ("¥1,500" or "1,500円"). Dates as \
    yyyy年mm月dd日; era names (令和, etc.) accepted when contextually \
    appropriate. 24h time with colon (14:30). Numbers under 10 may be \
    written in kanji (一, 二, 三) for formal writing; western digits \
    are fine for technical content. No spaces between words.
    """
}

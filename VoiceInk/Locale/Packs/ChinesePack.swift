import Foundation

/// Generic Chinese pack covering zh, zh-CN, zh-TW, zh-HK, zh-SG. Output-only
/// Tier 1: Whisper prompt seed in Simplified Chinese (the larger speaker
/// population) plus a format-rules block covering the dominant Chinese
/// conventions. Traditional-character regions (TW, HK) read Simplified prompts
/// fine for biasing purposes; curated zh-TW / zh-HK packs can ship later for
/// region-specific glyph preferences and currency.
struct ChinesePack: LocalePack {
    let primarySubtag: String = "zh"
    let displayName: String = "Chinese"

    let normalizerRules: [NormalizerRule] = []
    let wordReplacements: [(original: String, replacement: String)] = []
    let vocabularyTerms: [String] = []
    let fillerWords: [String] = []

    let whisperPromptSeeds: [String: String] = [
        "default": "你好,你最近怎么样?今天我们要回顾项目的下一阶段。",
        "technical": "工程团队审查了 Kubernetes 部署、API 调用和 PostgreSQL 数据库的延迟。"
    ]

    let aiPromptFormatRules: String = """
    zh: use the variant matching the user context — Simplified Chinese for \
    zh-CN/zh-SG (RMB ¥), Traditional Chinese for zh-TW (NT$) and zh-HK (HK$). \
    Full-width punctuation throughout: ,。、!?:;""''(). Dates as \
    yyyy年mm月dd日 or yyyy-mm-dd in formal/technical writing. Currency \
    typically without decimals at the integer level. No spaces between words. \
    Mixed Latin/Chinese text uses half-width punctuation around the Latin run.
    """
}

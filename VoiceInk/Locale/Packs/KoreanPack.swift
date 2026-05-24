import Foundation

/// Generic Korean pack. Output-only Tier 1: Whisper prompt seed in Korean
/// plus a format-rules block covering the dominant Korean conventions.
struct KoreanPack: LocalePack {
    let primarySubtag: String = "ko"
    let displayName: String = "Korean"

    let normalizerRules: [NormalizerRule] = []
    let wordReplacements: [(original: String, replacement: String)] = []
    let vocabularyTerms: [String] = []
    let fillerWords: [String] = []

    let whisperPromptSeeds: [String: String] = [
        "default": "안녕하세요, 잘 지내세요? 오늘은 프로젝트의 다음 단계를 검토하겠습니다.",
        "technical": "엔지니어링 팀은 Kubernetes 배포, API 호출, PostgreSQL 데이터베이스 지연 시간을 검토했습니다."
    ]

    let aiPromptFormatRules: String = """
    ko: standard Korean (한글) conventions. Currency: ₩ with no decimals \
    ("₩1,500" or "1,500원"). Dates as yyyy. mm. dd. or yyyy년 mm월 dd일. \
    24h time with colon (14:30). Sentence-final punctuation uses western \
    "." and "?" — full-width punctuation is uncommon in modern usage. \
    Spaces between words ("띄어쓰기") are required; do not collapse them.
    """
}

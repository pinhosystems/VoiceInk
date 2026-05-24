import Foundation

/// Curated Korean pack. Provides filler words, chat-abbreviation expansions
/// (consonant-only shorthand common in Korean messaging), vocabulary biasing
/// for Korean institutions, chaebols, and documents, normalization for phone
/// numbers and 주민등록번호, Whisper prompt seeds across domains, and LLM
/// formatting conventions tuned to standard Korean (한글) usage.
struct KoreanPack: LocalePack {
    let primarySubtag: String = "ko"
    let displayName: String = "Korean"

    // MARK: - Filler Words

    let fillerWords: [String] = [
        "음", "어", "그", "그러니까", "뭐",
        "아니", "좀", "이제", "근데", "약간",
        "진짜", "걍", "그냥", "아 맞다", "일단",
        "솔직히", "사실"
    ]

    // MARK: - Word Replacements

    let wordReplacements: [(original: String, replacement: String)] = [
        ("ㅇㅇ", "응"),
        ("ㄴㄴ", "아니"),
        ("ㅋㅋ, ㅋㅋㅋ", "（笑）"),
        ("ㅎㅎ", "（笑）"),
        ("ㄱㅅ", "감사"),
        ("ㅈㅅ", "죄송"),
        ("ㄱㄱ", "고고"),
        ("ㅇㅋ", "오케이")
    ]

    // MARK: - Vocabulary Terms

    let vocabularyTerms: [String] = [
        // 국가 기관
        "국회", "대법원", "헌법재판소",
        "국세청", "금융감독원", "금융위원회",
        "공정거래위원회", "감사원", "국정원",
        "행정안전부", "기획재정부", "법무부",
        "대통령실", "국무총리실",

        // 기업
        "삼성", "삼성전자", "LG", "LG전자",
        "현대", "현대자동차", "기아",
        "SK", "SK하이닉스", "SK텔레콤",
        "네이버", "카카오", "쿠팡",
        "롯데", "포스코", "한화",
        "셀트리온", "크래프톤", "넥슨",
        "배달의민족", "토스", "당근마켓",

        // 교육
        "서울대", "서울대학교",
        "연세대", "연세대학교",
        "고려대", "고려대학교",
        "KAIST", "포항공대", "POSTECH",
        "성균관대", "한양대", "중앙대", "경희대",
        "수능", "대학수학능력시험",

        // 문서 및 식별자
        "주민등록번호", "사업자등록번호",
        "운전면허증", "여권", "건강보험증",
        "공인인증서", "공동인증서",

        // 지리
        "서울", "부산", "인천", "대구", "대전",
        "광주", "울산", "세종", "제주도",
        "강남", "홍대", "이태원", "명동",

        // 금융
        "국민은행", "신한은행", "하나은행", "우리은행",
        "카카오뱅크", "토스뱅크", "케이뱅크",
        "코스피", "코스닥", "한국은행"
    ]

    // MARK: - Normalizer Rules

    let normalizerRules: [NormalizerRule] = [
        // Korean mobile phone: 010-1234-5678
        NormalizerRule(
            pattern: #"(?<!\d)(01[016789])[\s.-]*(\d{3,4})[\s.-]*(\d{4})(?!\d)"#,
            options: [],
            replacement: "$1-$2-$3",
            description: "Normalize Korean mobile phone number (010-XXXX-XXXX)"
        ),

        // Korean landline: 02-1234-5678 or 031-123-4567
        NormalizerRule(
            pattern: #"(?<!\d)(0[2-6][0-9]?)[\s.-]*(\d{3,4})[\s.-]*(\d{4})(?!\d)"#,
            options: [],
            replacement: "$1-$2-$3",
            description: "Normalize Korean landline number (0XX-XXXX-XXXX)"
        ),

        // 주민등록번호: 6 digits dash 7 digits (######-#######)
        NormalizerRule(
            pattern: #"(?<!\d)(\d{6})[\s.-]*(\d{7})(?!\d)"#,
            options: [],
            replacement: "$1-$2",
            description: "Normalize 주민등록번호 format (######-#######)"
        )
    ]

    // MARK: - Whisper Prompt Seeds

    let whisperPromptSeeds: [String: String] = [
        "default": """
            안녕하세요, 잘 지내세요? 오늘은 2026년 5월 15일이고, 회의는 14시 30분에 \
            시작합니다. 합의된 금액은 ₩1,500,000이며, 부가세 포함 시 ₩1,650,000까지 \
            올라갈 수 있습니다. 이미 팀에 이메일을 보냈고, 내일까지 김 과장님, 이 대리님, \
            박 사원님과 확인해야 합니다. 제안서를 다시 검토하는 것을 잊지 마세요. \
            서울 강남 방면 교통은 원활하지만, 내비게이션에 올림픽대로 정체가 표시됩니다.
            """,
        "technical": """
            소프트웨어 아키텍처에 대해 한국어로 논의하고 있습니다. 오늘은 2026년 5월 15일이고, \
            Node.js 백엔드의 REST API, React와 TypeScript 프론트엔드, AWS에서 Docker와 \
            Kubernetes를 통한 배포, Grafana 모니터링, PostgreSQL 데이터베이스, Redis 캐시를 \
            검토합니다. 풀 리퀘스트, 코드 리뷰, CI/CD, async/await, 콜백, 엔드포인트, \
            JSON 페이로드, JWT, OAuth, gRPC, 마이크로서비스 아키텍처.
            """,
        "medical": """
            한국어 진료 기록입니다. 환자 52세, 4일 전부터 호흡곤란 호소, 고혈압으로 \
            암로디핀 5mg 복용 중, 제2형 당뇨병으로 메트포르민 1000mg 복용 중, \
            LDL 콜레스테롤 160, 공복혈당 130. 혈액검사(CBC), AST, ALT, 크레아티닌, \
            BUN, 심초음파 검사 처방. 건강보험, 주민등록번호, 의료기관 코드.
            """,
        "legal": """
            한국어 소장입니다. 원고: 김철수, 주민등록번호 850101-1234567, \
            서울특별시 강남구 테헤란로 123, 우편번호 06236. 원고는 민법 제750조에 \
            근거하여 손해배상을 청구합니다. 피고: 주식회사 알파, 사업자등록번호 \
            123-45-67890. 서울중앙지방법원, 대법원, 헌법재판소, 변호사, 소송대리인.
            """
    ]

    // MARK: - AI Prompt Format Rules

    let aiPromptFormatRules: String = """
        ko: standard Korean (한글) conventions. Use standard Korean punctuation: \
        period (.), comma (,), question mark (?). Currency: ₩ prefix with no \
        decimals ("₩1,500" or "1,500원"). Dates as yyyy년 mm월 dd일 or \
        yyyy. mm. dd. format. 24h time with 시/분 ("14시 30분") or colon \
        (14:30). Spaces between words (띄어쓰기) are required; do not collapse \
        them. Numbers use comma as thousands separator ("1,000,000"). Full-width \
        punctuation is uncommon in modern usage — prefer half-width. Honorific \
        levels should default to 합쇼체 (formal) unless context indicates \
        otherwise.
        """

    // MARK: - Normalization Examples

    let normalizationExamples: [(before: String, after: String)] = [
        ("전화번호 010 1234 5678", "전화번호 010-1234-5678"),
        ("주민번호 8501011234567", "주민번호 850101-1234567"),
        ("연락처 02 555 1234", "연락처 02-555-1234")
    ]
}

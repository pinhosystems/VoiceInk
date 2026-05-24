import Foundation

/// Curated Japanese pack (ja). Full Tier 2: filler words, word replacements,
/// vocabulary biasing, normalization (full-width digit conversion, phone/postal
/// formatting), Whisper prompt seeds, and AI format rules for Japanese text
/// conventions. Japanese uses no spaces between words, full-width punctuation
/// (。、), and a mix of kanji, hiragana, katakana, and Latin scripts.
struct JapanesePack: LocalePack {
    let primarySubtag: String = "ja"
    let displayName: String = "Japanese"

    // MARK: - Filler Words

    let fillerWords: [String] = [
        // Classic hesitation markers
        "えーと", "えーっと", "えー", "あの", "あのー",
        // Soft hedges / discourse markers used as fillers
        "まあ", "まあまあ", "なんか", "ほら", "その",
        // Paraphrasing fillers
        "なんていうか", "なんというか", "いわゆる", "つまり", "ようするに",
        // Filler usage of otherwise meaningful words
        "ちょっと", "そうですね", "ですね",
        // Trailing hedges that add no content
        "なんですけど", "なんですが", "みたいな",
        // Backchannels that STT captures from speaker overlap
        "うん", "ええ", "はい", "ああ"
    ]

    // MARK: - Word Replacements (Abbreviation Expansions)

    let wordReplacements: [(original: String, replacement: String)] = [
        // Internet slang / shorthand
        ("w, ww, www", "（笑）"),
        ("おk, おK", "OK"),
        ("りょ, り", "了解"),
        ("おつ", "お疲れ様"),
        ("あざす, あざ", "ありがとうございます"),
        ("すいません", "すみません"),
        ("よろ", "よろしく"),
        ("おめ", "おめでとう"),
        ("わず", "終わった"),
        ("kwsk", "詳しく"),
        ("うぽつ", "アップロードお疲れ様"),
        ("おけ", "OK"),
        ("なる", "なるほど"),
        ("それな", "そうだね"),
        // Common STT mis-hearings where a normalized form helps
        ("てゆうか, ていうか, っていうか", "というか"),
        ("ぶっちゃけ", "正直に言うと")
    ]

    // MARK: - Vocabulary Terms (STT Biasing)

    let vocabularyTerms: [String] = [
        // Honorific suffixes (often dropped or garbled by STT)
        "様", "さん", "先生", "殿", "さま", "君", "ちゃん",

        // Government agencies and terms
        "内閣府", "厚生労働省", "国税庁", "金融庁", "経済産業省",
        "総務省", "文部科学省", "法務省", "外務省", "防衛省",
        "デジタル庁", "環境省", "農林水産省", "国土交通省",
        "マイナンバー", "マイナンバーカード", "マイナ保険証",
        "確定申告", "源泉徴収", "年末調整", "住民税", "所得税",
        "消費税", "法人税", "固定資産税", "相続税",

        // Major companies
        "ソフトバンク", "楽天", "トヨタ", "ソニー", "任天堂",
        "NTT", "NTTドコモ", "KDDI", "au",
        "パナソニック", "日立", "東芝", "富士通", "シャープ",
        "三菱", "三井", "住友", "みずほ", "野村",
        "リクルート", "サイバーエージェント", "メルカリ", "LINE",
        "DeNA", "グリー", "楽天モバイル", "PayPay",

        // Technology terms used in Japanese (katakana loanwords)
        "アプリ", "サーバー", "データベース", "クラウド",
        "デプロイ", "リポジトリ", "プルリクエスト", "マージ",
        "コンテナ", "マイクロサービス", "インフラ", "バックエンド",
        "フロントエンド", "フレームワーク", "ライブラリ",
        "リファクタリング", "スプリント", "アジャイル", "スクラム",
        "Kubernetes", "Docker", "GitHub", "AWS", "Azure", "GCP",
        "PostgreSQL", "MySQL", "Redis", "Elasticsearch",
        "TypeScript", "React", "Next.js", "Node.js", "Python",
        "API", "REST", "GraphQL", "gRPC", "WebSocket",
        "CI/CD", "DevOps", "SRE", "OAuth", "JWT",

        // Education
        "東京大学", "京都大学", "大阪大学", "東北大学", "名古屋大学",
        "早稲田大学", "慶應義塾大学", "上智大学", "明治大学", "立教大学",
        "早稲田", "慶應", "慶応",
        "大学院", "修士", "博士", "学士",
        "文部科学省", "科研費", "JSPS",

        // Finance and markets
        "日経平均", "日経225", "TOPIX", "東証", "マザーズ",
        "日本銀行", "日銀", "円", "円安", "円高",
        "確定拠出年金", "iDeCo", "NISA", "つみたてNISA",
        "株式会社", "有限会社", "合同会社",

        // Common proper nouns STT struggles with
        "東京", "大阪", "名古屋", "北海道", "沖縄", "福岡", "横浜",
        "新幹線", "山手線", "東海道",
        "コンビニ", "ファミマ", "セブンイレブン", "ローソン",
        "ヤマト運輸", "佐川急便", "日本郵便",

        // Medical / common life terms
        "健康保険", "国民健康保険", "介護保険", "厚生年金", "国民年金",
        "処方箋", "診察", "検査", "手術", "入院", "通院"
    ]

    // MARK: - Normalizer Rules

    let normalizerRules: [NormalizerRule] = [
        // Full-width digits → half-width (１２３ → 123)
        NormalizerRule(
            pattern: "[０-９]+",
            options: [],
            replacement: "",  // handled by customNormalize
            description: "Full-width digits to half-width (handled in customNormalize)"
        ),

        // Japanese phone number: 11 digits starting with 0 (mobile 090/080/070)
        NormalizerRule(
            pattern: #"(?<!\d)(0[789]0)\s*(\d{4})\s*(\d{4})(?!\d)"#,
            options: [],
            replacement: "$1-$2-$3",
            description: "Format mobile phone: 090-1234-5678"
        ),

        // Japanese phone number: 10 digits (landline, e.g. 03-1234-5678)
        NormalizerRule(
            pattern: #"(?<!\d)(0\d)\s*(\d{4})\s*(\d{4})(?!\d)"#,
            options: [],
            replacement: "$1-$2-$3",
            description: "Format landline phone: 03-1234-5678"
        ),

        // Postal code: 7 digits possibly prefixed with 〒
        NormalizerRule(
            pattern: #"〒?\s*(\d{3})\s*(\d{4})"#,
            options: [],
            replacement: "〒$1-$2",
            description: "Format postal code: 〒123-4567"
        )
    ]

    // MARK: - Whisper Prompt Seeds

    let whisperPromptSeeds: [String: String] = [
        "default": """
            こんにちは。今日は2026年5月15日で、プロジェクトの進捗を確認します。\
            次のマイルストーンは6月30日で、予算は150万円です。\
            田中さんと佐藤先生に確認を取ってから、来週の会議で最終決定します。\
            資料は共有フォルダにアップロード済みです。ご確認ください。
            """,
        "technical": """
            エンジニアリングチームはKubernetesクラスタのデプロイパイプラインを見直しました。\
            APIのレイテンシが200ミリ秒を超えている問題について、PostgreSQLのクエリ最適化と\
            Redisキャッシュの導入で改善できる見込みです。CI/CDはGitHub Actionsで回しており、\
            プルリクエストごとにステージング環境へ自動デプロイしています。\
            Dockerイメージのサイズをマルチステージビルドで半分にしました。\
            次のスプリントではgRPCへの移行とOpenTelemetryの導入を予定しています。
            """,
        "business": """
            第3四半期の売上は前年同期比12%増の45億円でした。\
            営業利益率は8.5%で、日経平均との相関を考慮すると堅調な推移です。\
            確定申告の時期に向けて、源泉徴収票の発行準備を進めています。\
            来月の取締役会で中期経営計画の修正案を提出する予定です。
            """
    ]

    // MARK: - AI Prompt Format Rules

    let aiPromptFormatRules: String = """
        ja: standard Japanese conventions. Use full-width punctuation throughout: \
        句点「。」for sentence ends, 読点「、」for clause separation, \
        鉤括弧「」for quotation, 二重鉤括弧『』for nested quotes or titles. \
        Currency: \"¥1,500\" or \"1,500円\" — no decimal places (yen has no subunit). \
        Dates: yyyy年mm月dd日; era names (令和, 平成) accepted when contextually \
        appropriate (e.g., official documents). 24h time with colon (14:30) or \
        Japanese style (14時30分). Numbers: use Arabic numerals for quantities, \
        amounts, and measurements (3個, 500g, 1,200円); use kanji numerals for \
        idiomatic counters and formal contexts (一人, 二つ, 第三). \
        Honorifics: preserve さん, 様, 先生, 殿 as spoken — never drop or add \
        honorifics the speaker did not use. No spaces between Japanese words; \
        insert a half-width space only around Latin/numeric runs embedded in \
        Japanese text (e.g., \"来週の meeting は14時から\"). \
        Particles: do not correct particles (は/が, に/で) unless clearly a \
        transcription error — speaker intent takes priority.
        """

    // MARK: - Custom Normalize (full-width digit conversion)

    var customNormalize: ((String) -> String)? {
        { JapaneseNormalizer.normalize($0) }
    }

    let normalizationExamples: [(before: String, after: String)] = [
        ("電話番号は０９０１２３４５６７８です", "電話番号は090-1234-5678です"),
        ("郵便番号は１２３４５６７です", "郵便番号は〒123-4567です"),
        ("金額は１５００円です", "金額は1500円です"),
        ("〒 1234567宛てに送付", "〒123-4567宛てに送付")
    ]
}

// MARK: - File-private normalization implementation

/// Japanese-specific text normalization applied AFTER raw STT output and word
/// replacements, but BEFORE the AI enhancement step. Handles full-width to
/// half-width digit conversion, phone number formatting, and postal code
/// formatting.
private enum JapaneseNormalizer {
    /// Full-width digit characters mapped to half-width equivalents.
    private static let fullWidthDigits: [Character: Character] = [
        "０": "0", "１": "1", "２": "2", "３": "3", "４": "4",
        "５": "5", "６": "6", "７": "7", "８": "8", "９": "9"
    ]

    static func normalize(_ text: String) -> String {
        var result = convertFullWidthDigits(text)
        result = formatPostalCode(result)
        result = formatMobilePhone(result)
        result = formatLandlinePhone(result)
        return result
    }

    // MARK: - Full-width → half-width digits

    /// Converts all full-width digit characters (０-９) to their half-width
    /// equivalents (0-9). This is the most common normalization needed for
    /// Japanese STT output, which often transcribes numbers in full-width.
    private static func convertFullWidthDigits(_ text: String) -> String {
        var output = ""
        output.reserveCapacity(text.count)
        for char in text {
            if let halfWidth = fullWidthDigits[char] {
                output.append(halfWidth)
            } else {
                output.append(char)
            }
        }
        return output
    }

    // MARK: - Postal code

    /// Formats 7-digit sequences (optionally preceded by 〒) as 〒XXX-XXXX.
    /// Runs after full-width conversion so digits are already half-width.
    private static func formatPostalCode(_ text: String) -> String {
        let pattern = #"〒?\s*(\d{3})\s*(\d{4})"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        var output = ""
        var cursor = text.startIndex

        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match,
                  let fullRange = Range(match.range, in: text),
                  let g1 = Range(match.range(at: 1), in: text),
                  let g2 = Range(match.range(at: 2), in: text)
            else { return }

            output.append(contentsOf: text[cursor..<fullRange.lowerBound])
            output.append("〒\(text[g1])-\(text[g2])")
            cursor = fullRange.upperBound
        }
        output.append(contentsOf: text[cursor..<text.endIndex])
        return output
    }

    // MARK: - Mobile phone

    /// Formats 11-digit mobile numbers (0[789]0 XXXX XXXX) as 0X0-XXXX-XXXX.
    private static func formatMobilePhone(_ text: String) -> String {
        let pattern = #"(?<!\d)(0[789]0)\s*(\d{4})\s*(\d{4})(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        var output = ""
        var cursor = text.startIndex

        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match,
                  let fullRange = Range(match.range, in: text),
                  let g1 = Range(match.range(at: 1), in: text),
                  let g2 = Range(match.range(at: 2), in: text),
                  let g3 = Range(match.range(at: 3), in: text)
            else { return }

            output.append(contentsOf: text[cursor..<fullRange.lowerBound])
            output.append("\(text[g1])-\(text[g2])-\(text[g3])")
            cursor = fullRange.upperBound
        }
        output.append(contentsOf: text[cursor..<text.endIndex])
        return output
    }

    // MARK: - Landline phone

    /// Formats 10-digit landline numbers (0X XXXX XXXX) as 0X-XXXX-XXXX.
    /// Only fires when preceded by a 2-digit area code starting with 0.
    private static func formatLandlinePhone(_ text: String) -> String {
        let pattern = #"(?<!\d)(0\d)\s*(\d{4})\s*(\d{4})(?!\d)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return text
        }
        let range = NSRange(text.startIndex..., in: text)
        var output = ""
        var cursor = text.startIndex

        regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            guard let match,
                  let fullRange = Range(match.range, in: text),
                  let g1 = Range(match.range(at: 1), in: text),
                  let g2 = Range(match.range(at: 2), in: text),
                  let g3 = Range(match.range(at: 3), in: text)
            else { return }

            output.append(contentsOf: text[cursor..<fullRange.lowerBound])
            output.append("\(text[g1])-\(text[g2])-\(text[g3])")
            cursor = fullRange.upperBound
        }
        output.append(contentsOf: text[cursor..<text.endIndex])
        return output
    }
}

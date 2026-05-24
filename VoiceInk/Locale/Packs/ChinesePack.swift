import Foundation

/// Generic Chinese pack covering zh, zh-CN, zh-TW, zh-HK, zh-SG.
/// Simplified Chinese as primary (larger speaker population); Traditional-
/// character regions read Simplified seeds fine for biasing. Curated zh-TW /
/// zh-HK packs can ship later for region-specific glyph and currency prefs.
struct ChinesePack: LocalePack {
    let primarySubtag: String = "zh"
    let displayName: String = "Chinese"

    // MARK: - Filler Words

    let fillerWords: [String] = [
        "嗯", "啊", "呃", "那个", "就是", "然后",
        "这个", "对对对", "是的是的", "怎么说呢",
        "反正", "其实", "基本上", "总之", "大概",
        "所以说", "你知道吗", "就是说", "我觉得吧",
        "说实话", "老实说", "不是", "就那个"
    ]

    // MARK: - Word Replacements

    let wordReplacements: [(original: String, replacement: String)] = [
        ("木有", "没有"),
        ("酱紫", "这样子"),
        ("表", "不要"),
        ("灰常", "非常"),
        ("童鞋", "同学"),
        ("盆友", "朋友"),
        ("辣么", "那么"),
        ("肿么", "怎么"),
        ("神马", "什么"),
        ("鸡冻", "激动"),
        ("稀饭", "喜欢"),
        ("素", "是"),
        ("介样", "这样")
    ]

    // MARK: - Vocabulary Terms

    let vocabularyTerms: [String] = [
        // Government / institutions
        "国务院", "全国人大", "政协", "中纪委",
        "最高人民法院", "最高人民检察院",
        "国家税务总局", "中国人民银行", "银保监会", "证监会",
        "发改委", "工信部", "商务部", "外交部",
        "公安部", "教育部", "科技部",

        // Companies / brands
        "阿里巴巴", "腾讯", "百度", "字节跳动", "华为",
        "小米", "京东", "美团", "拼多多", "网易",
        "比亚迪", "蔚来", "理想汽车", "小鹏汽车",
        "中国移动", "中国联通", "中国电信",

        // Education
        "清华大学", "北京大学", "复旦大学", "浙江大学",
        "上海交通大学", "南京大学", "中国科学院",
        "高考", "研究生", "博士后",

        // Finance / documents
        "身份证", "社保", "公积金", "营业执照",
        "统一社会信用代码", "纳税人识别号",
        "人民币", "支付宝", "微信支付",
        "上证指数", "深证成指", "沪深300",
        "A股", "港股通", "科创板",

        // Geography
        "北京", "上海", "广州", "深圳", "杭州",
        "成都", "重庆", "武汉", "南京", "西安",
        "香港", "澳门", "台北",

        // Tech terms (Chinese equivalents STT may struggle with)
        "服务器", "数据库", "云计算", "人工智能",
        "机器学习", "深度学习", "容器化", "微服务",
        "接口", "前端", "后端", "运维", "部署"
    ]

    // MARK: - Normalizer Rules

    let normalizerRules: [NormalizerRule] = []

    var customNormalize: ((String) -> String)? {
        { text in
            let fullToHalf: [Character: Character] = [
                "１": "1", "２": "2", "３": "3", "４": "4", "５": "5",
                "６": "6", "７": "7", "８": "8", "９": "9", "０": "0"
            ]
            var result = text
            for (full, half) in fullToHalf {
                result = result.replacingOccurrences(of: String(full), with: String(half))
            }
            // Format phone: 1xx xxxx xxxx
            let phonePattern = try? NSRegularExpression(pattern: "\\b(1[3-9]\\d)(\\d{4})(\\d{4})\\b")
            if let regex = phonePattern {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "$1 $2 $3")
            }
            return result
        }
    }

    // MARK: - Whisper Prompt Seeds

    let whisperPromptSeeds: [String: String] = [
        "default": "你好,你最近怎么样?今天我们要回顾项目的下一阶段。",
        "technical": "工程团队审查了 Kubernetes 部署、API 调用和 PostgreSQL 数据库的延迟。",
        "medical": "患者主诉头痛三天,伴有低热。体温37.5度,血压120/80毫米汞柱。",
        "legal": "根据《中华人民共和国民法典》第五百零九条,当事人应当按照约定全面履行自己的义务。"
    ]

    // MARK: - AI Prompt Format Rules

    let aiPromptFormatRules: String = """
    zh: use the variant matching the user context — Simplified Chinese for \
    zh-CN/zh-SG (RMB ¥), Traditional Chinese for zh-TW (NT$) and zh-HK (HK$). \
    Full-width punctuation throughout: ,。、!?:;""''(). Dates as \
    yyyy年mm月dd日 or yyyy-mm-dd in formal/technical writing. Currency \
    typically without decimals at the integer level. No spaces between words. \
    Mixed Latin/Chinese text uses half-width punctuation around the Latin run. \
    Arabic numerals for amounts > 10; Chinese characters for small counts \
    and idioms (三个, 五十步笑百步). Measure words (量词) must be preserved.
    """

    // MARK: - Normalization Examples

    let normalizationExamples: [(before: String, after: String)] = [
        (before: "１３８１２３４５６７８", after: "138 1234 5678"),
        (before: "２０２６年", after: "2026年")
    ]
}

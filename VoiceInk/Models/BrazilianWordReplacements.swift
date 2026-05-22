import Foundation

/// Canonical list of Brazilian-Portuguese chat abbreviations that are routinely
/// dictated but should be expanded for written output. The user opts in via a
/// "Adicionar abreviações pt-BR" button in the Word Replacement settings; entries
/// they already have are not duplicated.
///
/// Each item maps a comma-separated set of triggers ("vc, vcs") to a canonical
/// expansion ("você, vocês"). Triggers are case-insensitive and matched with
/// Unicode word boundaries by `WordReplacementService`, so "PQ" in caps and
/// "pq?" both fire — but plain substrings inside other words ("aquilo" → no
/// match for "aqu") are safe.
///
/// Entries deliberately exclude very ambiguous abbreviations:
/// - "n" (could be "não" or just the letter)
/// - "s" (could be "sim" or initials)
/// - "k" (used as "ok" but also a unit/variable name)
///
/// Adding those would create false positives in technical dictation; leave them
/// to the user's manual list if they want them.
enum BrazilianWordReplacements {

    /// Each tuple is `(originalText, replacementText)`. `originalText` may contain
    /// comma-separated alternatives following the same convention used elsewhere
    /// in `WordReplacement.originalText`.
    static let canonicalReplacements: [(original: String, replacement: String)] = [
        ("vc, vcs", "você"),
        ("tb, tbm, tmb", "também"),
        ("pq, pq?", "porque"),
        ("obg, obgd, obrg", "obrigado"),
        ("blz", "beleza"),
        ("vlw", "valeu"),
        ("fds", "fim de semana"),
        ("td, tds", "tudo"),
        ("msg, msgs", "mensagem"),
        ("msm", "mesmo"),
        ("mt, mto, mta, mtos, mtas", "muito"),
        ("mds", "meu Deus"),
        ("hj", "hoje"),
        ("amh, amh.", "amanhã"),
        ("ontm", "ontem"),
        ("eh", "é"),
        ("c/", "com"),
        ("s/", "sem"),
        ("p/", "para"),
        ("q", "que"),
        ("qd, qdo, qnd, qndo", "quando"),
        ("qm", "quem"),
        ("qto, qts", "quanto"),
        ("dps", "depois"),
        ("agr", "agora"),
        ("td bem", "tudo bem"),
        ("tava, tavam", "estava"),
        ("to, tô", "estou"),
        ("ta, tá", "está"),
        ("vamo, vamu", "vamos"),
        ("brigado, brigadu, brigada", "obrigado"),
        ("flw", "falou"),
        ("hr, hrs", "hora"),
        ("min", "minuto"),
        ("seg", "segundo"),
        ("sex", "sexta"),
        ("sab", "sábado"),
        ("dom", "domingo"),
        ("seg.", "segunda"),
        ("ter.", "terça"),
        ("qua.", "quarta"),
        ("qui.", "quinta"),
        ("aki", "aqui"),
        ("akele", "aquele"),
        ("aqui, aki, aqi", "aqui")
    ]

    static var count: Int { canonicalReplacements.count }
}

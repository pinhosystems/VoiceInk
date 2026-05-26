import Foundation

class FillerWordManager: ObservableObject {
    static let shared = FillerWordManager()

    /// Filler words em inglês — válidos para qualquer idioma como ruído universal de hesitação.
    static let defaultFillerWords = [
        "uh", "um", "uhm", "umm", "uhh", "uhhh",
        "hmm", "hm", "mmm", "mm", "mh", "ehh"
    ]

    /// Vícios de linguagem típicos do português brasileiro falado. Aplicados em adição
    /// aos defaults quando o idioma selecionado começa com "pt". Os termos foram escolhidos
    /// para serem agressivamente seguros: removem o filler sem alterar conteúdo legítimo.
    /// Termos comuns mas ambíguos ("então", "olha", "bem", "mas", "aí") ficaram de fora
    /// porque também aparecem em uso conectivo legítimo — adicioná-los apagaria texto útil.
    static let brazilianPortugueseFillerWords = [
        "né", "tipo", "aham", "uhum", "ahã",
        "tá", "tá bom", "tá certo",
        "sei lá", "sabe", "tipo assim",
        "putz", "eita", "nossa", "caramba"
    ]

    private let fillerWordsKey = "FillerWords"
    private let removeFillerWordsKey = "RemoveFillerWords"

    @Published var fillerWords: [String] {
        didSet {
            UserDefaults.standard.set(fillerWords, forKey: fillerWordsKey)
        }
    }

    var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: removeFillerWordsKey)
    }

    /// Effective filler list applied at removal time. The persisted user list
    /// is union-merged with the active `LocalePack`'s `fillerWords` (if any).
    /// Resolution goes through `LocalePackRegistry`, so pt-BR pulls the BR
    /// list, pt-PT/pt-AO/etc. pull the (empty) generic Portuguese list, and
    /// other locales contribute whatever their pack ships. UserDefaults stays
    /// untouched — the union is computed on demand.
    var effectiveFillerWords: [String] {
        let selectedLanguage = LanguageResolver.effectiveSTTCode()
        guard let packFillers = LocalePackRegistry.pack(for: selectedLanguage)?.fillerWords,
              !packFillers.isEmpty
        else {
            return fillerWords
        }
        var seen = Set<String>(fillerWords.map { $0.lowercased() })
        var combined = fillerWords
        for word in packFillers {
            let key = word.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                combined.append(word)
            }
        }
        return combined
    }

    private init() {
        if let saved = UserDefaults.standard.stringArray(forKey: fillerWordsKey) {
            self.fillerWords = saved
        } else {
            self.fillerWords = Self.defaultFillerWords
        }
    }

    func addWord(_ word: String) -> Bool {
        let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        guard !fillerWords.contains(where: { $0.lowercased() == normalized }) else { return false }
        fillerWords.append(normalized)
        return true
    }

    func removeWord(_ word: String) {
        fillerWords.removeAll { $0.lowercased() == word.lowercased() }
    }

}

import Foundation
import SwiftUI
import SwiftData

class CustomVocabularyService {
    static let shared = CustomVocabularyService()

    private init() {}

    /// Builds the comma-separated vocabulary string injected into the LLM
    /// system message. Delegates to `VocabularyResolver` so the LLM hint and
    /// the STT `keyterm` bias come from the same source and stay in sync —
    /// every prompt template's declared `vocabularyDomains` flow through
    /// the same resolver so xAI/Deepgram and the LLM see identical terms.
    func getCustomVocabulary(from context: ModelContext) -> String {
        let terms = VocabularyResolver.resolveFromUserDefaults(context: context)
        return terms.joined(separator: ", ")
    }
}

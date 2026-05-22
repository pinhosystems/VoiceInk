import Foundation
import SwiftUI
import SwiftData

class CustomVocabularyService {
    static let shared = CustomVocabularyService()

    private init() {}

    /// Builds the comma-separated vocabulary string injected into the LLM
    /// system message. Delegates to `VocabularyResolver` so the LLM hint and
    /// the STT `keyterm` bias come from the same source and stay in sync —
    /// if a user picks the "Code (pt-BR)" template the LLM sees the same
    /// technical + brazilian + user vocabulary that xAI/Deepgram receive.
    func getCustomVocabulary(from context: ModelContext) -> String {
        let terms = VocabularyResolver.resolveFromUserDefaults(context: context)
        return terms.joined(separator: ", ")
    }
}

import Foundation
import SwiftData
import LLMkit

struct XAIProvider: CloudProvider {
    let modelProvider: ModelProvider = .xai
    let providerKey: String = "xAI"
    let languageCodes: [String]? = [
        "ar", "cs", "da", "nl", "en", "fil", "fr", "de", "hi", "id",
        "it", "ja", "ko", "mk", "ms", "fa", "pl", "pt", "ro", "ru",
        "es", "sv", "th", "tr", "vi"
    ]
    let includesAutoDetect: Bool = true

    var models: [CloudModel] {[
        CloudModel(
            name: "grok-stt",
            displayName: "Grok (xAI)",
            description: "xAI's Grok speech-to-text with real-time streaming and batch transcription",
            provider: .xai,
            speed: 0.99,
            accuracy: 0.98,
            isMultilingual: true,
            supportsStreaming: true,
            supportedLanguages: LanguageDictionary.forProvider(isMultilingual: true, provider: .xai)
        )
    ]}

    func transcribe(audioData: Data, fileName: String, apiKey: String, model: String, language: String?, prompt: String?, customVocabulary: [String], resourceTimeout: TimeInterval) async throws -> String {
        // `fillerWords: true` keeps the raw transcript so VoiceInk's own
        // FillerWordManager decides whether to strip them. `diarize` /
        // `multichannel` are intentionally omitted: dictation is single
        // speaker, mono mic input, and either flag would alter the response
        // shape parsed downstream.
        return try await XAIClient.transcribe(
            audioData: audioData,
            fileName: fileName,
            apiKey: apiKey,
            language: language,
            format: XAISettings.format,
            keyterm: customVocabulary.isEmpty ? nil : customVocabulary,
            fillerWords: XAISettings.keepFillerWords,
            resourceTimeout: resourceTimeout
        )
    }

    func makeStreamingProvider(modelContext: ModelContext) -> (any StreamingTranscriptionProvider)? {
        XAIStreamingProvider(modelContext: modelContext)
    }

    func verifyAPIKey(_ key: String) async -> (isValid: Bool, errorMessage: String?) {
        return await XAIClient.verifyAPIKey(key)
    }
}

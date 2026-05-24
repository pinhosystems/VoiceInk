import Foundation
import SwiftData
import LLMkit

/// OpenAI cloud transcription provider.
///
/// Targets the `/v1/audio/transcriptions` endpoint at `api.openai.com`. The
/// historical Whisper API (`whisper-1`) is still available and reliable;
/// `gpt-4o-transcribe` and `gpt-4o-mini-transcribe` (2024+) offer higher
/// accuracy at higher cost and lower latency respectively.
///
/// `LanguageDictionary.forProvider` routes a nil `languageCodes` to the full
/// list of Whisper-supported languages, matching the cloud API's behavior.
struct OpenAIProvider: CloudProvider {
    let modelProvider: ModelProvider = .openAI
    let providerKey: String = "OpenAI"
    let languageCodes: [String]? = nil
    let includesAutoDetect: Bool = false

    private static let baseURL = URL(string: "https://api.openai.com")!

    var models: [CloudModel] {[
        CloudModel(
            name: "gpt-4o-transcribe",
            displayName: "GPT-4o Transcribe (OpenAI)",
            description: "OpenAI's flagship speech-to-text model. Highest accuracy, multilingual.",
            provider: .openAI,
            speed: 0.55,
            accuracy: 0.98,
            isMultilingual: true,
            supportedLanguages: LanguageDictionary.forProvider(isMultilingual: true, provider: .openAI)
        ),
        CloudModel(
            name: "gpt-4o-mini-transcribe",
            displayName: "GPT-4o Mini Transcribe (OpenAI)",
            description: "Faster, cheaper GPT-4o speech-to-text. Multilingual.",
            provider: .openAI,
            speed: 0.75,
            accuracy: 0.95,
            isMultilingual: true,
            supportedLanguages: LanguageDictionary.forProvider(isMultilingual: true, provider: .openAI)
        ),
        CloudModel(
            name: "whisper-1",
            displayName: "Whisper v2 (OpenAI)",
            description: "Original OpenAI Whisper API. Multilingual, mature, stable pricing.",
            provider: .openAI,
            speed: 0.6,
            accuracy: 0.93,
            isMultilingual: true,
            supportedLanguages: LanguageDictionary.forProvider(isMultilingual: true, provider: .openAI)
        )
    ]}

    func transcribe(audioData: Data, fileName: String, apiKey: String, model: String, language: String?, prompt: String?, customVocabulary: [String], resourceTimeout: TimeInterval) async throws -> String {
        return try await OpenAITranscriptionClient.transcribe(
            baseURL: Self.baseURL,
            audioData: audioData,
            fileName: fileName,
            apiKey: apiKey,
            model: model,
            language: language,
            prompt: prompt,
            resourceTimeout: resourceTimeout
        )
    }

    func makeStreamingProvider(modelContext: ModelContext) -> (any StreamingTranscriptionProvider)? { nil }

    func verifyAPIKey(_ key: String) async -> (isValid: Bool, errorMessage: String?) {
        return await OpenAITranscriptionClient.verifyAPIKey(
            baseURL: Self.baseURL,
            apiKey: key
        )
    }
}

import Foundation
import LLMkit

/// Stateless API-key verifier driven by `ProviderEntry`. Mirrors the switch
/// in `AIService.verifyAPIKey(_:completion:)` but is decoupled from
/// `AIService.selectedProvider`, so the Providers tab can verify any
/// provider's credentials without first mutating the active LLM selection.
///
/// For STT-only providers (Cartesia) it routes through `CloudProvider`'s
/// dedicated verifier; for LLM-capable providers it uses the same client
/// the in-app enhancement code uses, so a successful verify here is a
/// reliable proof that the key will work for real requests.
enum ProviderVerifier {
    struct Result {
        let isValid: Bool
        let errorMessage: String?
    }

    static func verify(entry: ProviderEntry, apiKey: String) async -> Result {
        if entry.capabilities == [.stt] {
            guard let cloud = sttCloudProvider(for: entry) else {
                return .init(isValid: false, errorMessage: "No verifier configured for \(entry.displayName)")
            }
            let result = await cloud.verifyAPIKey(apiKey)
            return .init(isValid: result.isValid, errorMessage: result.errorMessage)
        }

        switch entry.id {
        case .anthropic:
            let r = await AnthropicLLMClient.verifyAPIKey(apiKey)
            return .init(isValid: r.isValid, errorMessage: r.errorMessage)
        case .elevenLabs:
            let r = await ElevenLabsClient.verifyAPIKey(apiKey)
            return .init(isValid: r.isValid, errorMessage: r.errorMessage)
        case .deepgram:
            let r = await DeepgramClient.verifyAPIKey(apiKey)
            return .init(isValid: r.isValid, errorMessage: r.errorMessage)
        case .mistral:
            let r = await MistralTranscriptionClient.verifyAPIKey(apiKey)
            return .init(isValid: r.isValid, errorMessage: r.errorMessage)
        case .soniox:
            let r = await SonioxClient.verifyAPIKey(apiKey)
            return .init(isValid: r.isValid, errorMessage: r.errorMessage)
        case .speechmatics:
            let r = await SpeechmaticsClient.verifyAPIKey(apiKey)
            return .init(isValid: r.isValid, errorMessage: r.errorMessage)
        case .assemblyAI:
            let r = await AssemblyAIClient.verifyAPIKey(apiKey)
            return .init(isValid: r.isValid, errorMessage: r.errorMessage)
        case .gemini:
            let r = await GeminiTranscriptionClient.verifyAPIKey(apiKey)
            return .init(isValid: r.isValid, errorMessage: r.errorMessage)
        case .openRouter:
            // OpenRouter requires a model; use the default if the user has not
            // yet picked one. Verification only confirms the key is recognized.
            let r = await OpenRouterClient.verifyAPIKey(apiKey, model: AIProvider.openRouter.defaultModel)
            return .init(isValid: r.isValid, errorMessage: r.errorMessage)
        default:
            return await verifyOpenAICompatible(entry: entry, apiKey: apiKey)
        }
    }

    private static func verifyOpenAICompatible(entry: ProviderEntry, apiKey: String) async -> Result {
        guard let aiRaw = entry.aiProviderRaw,
              let provider = AIProvider(rawValue: aiRaw),
              let baseURL = URL(string: provider.baseURL) else {
            return .init(isValid: false, errorMessage: "Invalid base URL configuration")
        }
        let r = await OpenAILLMClient.verifyAPIKey(
            baseURL: baseURL,
            apiKey: apiKey,
            model: provider.defaultModel
        )
        return .init(isValid: r.isValid, errorMessage: r.errorMessage)
    }

    private static func sttCloudProvider(for entry: ProviderEntry) -> (any CloudProvider)? {
        guard let raw = entry.modelProviderRaw,
              let mp = ModelProvider(rawValue: raw) else { return nil }
        return CloudProviderRegistry.provider(for: mp)
    }
}

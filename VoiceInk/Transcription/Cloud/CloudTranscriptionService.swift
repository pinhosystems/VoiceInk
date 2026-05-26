import Foundation
import SwiftData
import os
import LLMkit

enum CloudTranscriptionError: Error, LocalizedError {
    case unsupportedProvider
    case missingAPIKey
    case invalidAPIKey
    case audioFileNotFound
    case apiRequestFailed(statusCode: Int, message: String)
    case networkError(Error)
    case noTranscriptionReturned
    case dataEncodingError
    case timeout(seconds: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .unsupportedProvider:
            return "The model provider is not supported by this service."
        case .missingAPIKey:
            return "API key for this service is missing. Please configure it in the settings."
        case .invalidAPIKey:
            return "The provided API key is invalid."
        case .audioFileNotFound:
            return "The audio file to transcribe could not be found."
        case .apiRequestFailed(let statusCode, let message):
            return "The API request failed with status code \(statusCode): \(message)"
        case .networkError(let error):
            return "A network error occurred: \(error.localizedDescription)"
        case .noTranscriptionReturned:
            return "The API returned an empty or invalid response."
        case .dataEncodingError:
            return "Failed to encode the request body."
        case .timeout(let seconds):
            return "Transcription timed out after \(Int(seconds))s. Increase the timeout in AI Models → Transcription Request Timeout for longer audio."
        }
    }
}

class CloudTranscriptionService: TranscriptionService {
    /// Fallback when the user has not configured the timeout. Big enough for ~5 min of
    /// audio on most providers while still surfacing a real error before the user gives up.
    static let defaultTranscriptionTimeoutSeconds: TimeInterval = 120

    /// UserDefaults key for the user-configurable transcription resource timeout.
    static let transcriptionTimeoutSecondsKey = "TranscriptionTimeoutSeconds"

    /// Max attempts (including the initial one) before surfacing the last error to the caller.
    private static let maxTranscriptionAttempts = 3
    /// Backoff delays applied BEFORE attempts 2..N (nanoseconds). Length governs maxAttempts.
    private static let retryBackoffsNanos: [UInt64] = [500_000_000, 1_500_000_000]

    private let modelContext: ModelContext
    private lazy var openAICompatibleService = OpenAICompatibleTranscriptionService()
    private let logger = Logger(subsystem: "agabo.dev.voiceink", category: "CloudTranscriptionService")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        let audioData = try loadAudioData(from: audioURL)
        let fileName = audioURL.lastPathComponent
        let language = selectedLanguage(for: model)
        let resourceTimeout = Self.configuredResourceTimeout()

        var lastError: CloudTranscriptionError?
        for attempt in 1...Self.maxTranscriptionAttempts {
            do {
                return try await performTranscribe(
                    audioURL: audioURL,
                    audioData: audioData,
                    fileName: fileName,
                    model: model,
                    language: language,
                    resourceTimeout: resourceTimeout
                )
            } catch let error as CloudTranscriptionError {
                lastError = error
                guard attempt < Self.maxTranscriptionAttempts, Self.isRetryable(error) else {
                    throw error
                }
                let delay = Self.retryBackoffsNanos[attempt - 1]
                logger.warning("Cloud transcription attempt \(attempt, privacy: .public)/\(Self.maxTranscriptionAttempts, privacy: .public) failed (\(error.localizedDescription, privacy: .public)); retrying in \(Double(delay) / 1_000_000_000, format: .fixed(precision: 2), privacy: .public)s")
                try? await Task.sleep(nanoseconds: delay)
            }
        }
        throw lastError ?? CloudTranscriptionError.networkError(URLError(.unknown))
    }

    private func performTranscribe(
        audioURL: URL,
        audioData: Data,
        fileName: String,
        model: any TranscriptionModel,
        language: String?,
        resourceTimeout: TimeInterval
    ) async throws -> String {
        do {
            if model.provider == .custom {
                guard let customModel = model as? CustomCloudModel else {
                    throw CloudTranscriptionError.unsupportedProvider
                }
                return try await openAICompatibleService.transcribe(
                    audioURL: audioURL,
                    model: customModel,
                    resourceTimeout: resourceTimeout
                )
            }

            guard let cloudProvider = CloudProviderRegistry.provider(for: model.provider) else {
                throw CloudTranscriptionError.unsupportedProvider
            }
            let apiKey = try requireAPIKey(forProvider: cloudProvider.providerKey)
            return try await cloudProvider.transcribe(
                audioData: audioData,
                fileName: fileName,
                apiKey: apiKey,
                model: model.name,
                language: language,
                prompt: transcriptionPrompt(),
                customVocabulary: getCustomDictionaryTerms(),
                resourceTimeout: resourceTimeout
            )
        } catch let error as CloudTranscriptionError {
            throw error
        } catch let error as LLMKitError {
            throw mapLLMKitError(error, resourceTimeout: resourceTimeout)
        } catch {
            throw CloudTranscriptionError.networkError(error)
        }
    }

    /// Whether a cloud transcription error is worth retrying. Keep this conservative:
    /// only transient server/network conditions. Client misconfiguration (4xx auth,
    /// missing API key, unsupported provider), local encoding issues, and timeouts
    /// (already long by definition) are not retried.
    private static func isRetryable(_ error: CloudTranscriptionError) -> Bool {
        switch error {
        case .apiRequestFailed(let statusCode, _):
            return (500...599).contains(statusCode) || statusCode == 408 || statusCode == 429
        case .networkError:
            return true
        case .timeout,
             .noTranscriptionReturned,
             .dataEncodingError,
             .audioFileNotFound,
             .unsupportedProvider,
             .missingAPIKey,
             .invalidAPIKey:
            return false
        }
    }

    /// Reads the user-configured transcription resource timeout, falling back to a
    /// sensible default when the setting is missing or out of range.
    static func configuredResourceTimeout() -> TimeInterval {
        let stored = UserDefaults.standard.double(forKey: transcriptionTimeoutSecondsKey)
        guard stored > 0 else { return defaultTranscriptionTimeoutSeconds }
        return stored
    }

    // MARK: - Helpers

    private func loadAudioData(from url: URL) throws -> Data {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CloudTranscriptionError.audioFileNotFound
        }
        // Memory-map the audio file so its pages stay backed by the kernel page cache
        // instead of being copied into anonymous heap. For long recordings (tens of MB)
        // this keeps the process resident set small and lets the kernel reclaim pages
        // under memory pressure. A further win would be extending LLMkit's transcription
        // API to take a file URL and stream directly from disk into the HTTP body.
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    private func requireAPIKey(forProvider provider: String) throws -> String {
        guard let apiKey = APIKeyManager.shared.getAPIKey(forProvider: provider), !apiKey.isEmpty else {
            throw CloudTranscriptionError.missingAPIKey
        }
        return apiKey
    }

    /// Model-aware. Resolves the inherit-from-Settings sentinel AND
    /// validates the resulting code against the model's supported list
    /// (e.g. Settings "pt-BR" + ElevenLabs which only ships "pt" →
    /// returns "pt"). Without the model-aware step, a Settings choice
    /// like "pt-BR" reached the ElevenLabs API verbatim and got rejected
    /// because the provider does not accept regioned Portuguese codes.
    private func selectedLanguage(for model: any TranscriptionModel) -> String? {
        let lang = LanguageResolver.effectiveSTTCode(for: model)
        return (lang == "auto" || lang.isEmpty) ? nil : lang
    }

    private func transcriptionPrompt() -> String? {
        let prompt = UserDefaults.standard.string(forKey: "TranscriptionPrompt") ?? ""
        return prompt.isEmpty ? nil : prompt
    }

    private func getCustomDictionaryTerms() -> [String] {
        // Domain-aware resolution: the active prompt's `vocabularyDomains`
        // determines which buckets we pull from (user vocab, technical,
        // brazilian). Capped at 100 entries / 50 chars each — xAI's documented
        // limits for the `keyterm` field; other providers tolerate but ignore
        // the excess silently. Same list goes to the LLM enhancement step via
        // `CustomVocabularyService`, so STT bias and LLM hint stay in sync.
        return VocabularyResolver.resolveFromUserDefaults(context: modelContext)
    }

    private func mapLLMKitError(_ error: LLMKitError, resourceTimeout: TimeInterval) -> CloudTranscriptionError {
        switch error {
        case .missingAPIKey:
            return .missingAPIKey
        case .httpError(let statusCode, let message):
            return .apiRequestFailed(statusCode: statusCode, message: message)
        case .noResultReturned:
            return .noTranscriptionReturned
        case .encodingError:
            return .dataEncodingError
        case .timeout:
            return .timeout(seconds: resourceTimeout)
        case .networkError(let detail):
            return .networkError(NSError(domain: "LLMkit", code: -1, userInfo: [NSLocalizedDescriptionKey: detail]))
        case .invalidURL, .decodingError:
            return .networkError(error)
        }
    }
}

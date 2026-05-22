import Foundation
import LLMkit
import SwiftData

/// xAI streaming provider wrapping `LLMkit.XAIStreamingClient`.
///
/// Forwards `XAISettings.endpointingMs` plus the active prompt's vocabulary
/// domains (via `VocabularyResolver`) so the streaming endpoint gets the
/// same `keyterm` bias the REST endpoint receives. Decoupling vocabulary
/// from the LLM enhancement state means recording with enhancement off
/// still benefits from the bias. `filler_words` is forced on so VoiceInk's
/// FillerWordManager owns user-visible filler behavior; `diarize` is
/// omitted (dictation is single-speaker).
final class XAIStreamingProvider: StreamingTranscriptionProvider {

    private let client = LLMkit.XAIStreamingClient()
    private let modelContext: ModelContext
    private var eventsContinuation: AsyncStream<StreamingTranscriptionEvent>.Continuation?
    private var forwardingTask: Task<Void, Never>?

    private(set) var transcriptionEvents: AsyncStream<StreamingTranscriptionEvent>

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        var continuation: AsyncStream<StreamingTranscriptionEvent>.Continuation!
        transcriptionEvents = AsyncStream { continuation = $0 }
        eventsContinuation = continuation
    }

    deinit {
        forwardingTask?.cancel()
        eventsContinuation?.finish()
    }

    func connect(model: any TranscriptionModel, language: String?) async throws {
        guard let apiKey = APIKeyManager.shared.getAPIKey(forProvider: "xAI"), !apiKey.isEmpty else {
            throw StreamingTranscriptionError.missingAPIKey
        }

        forwardingTask?.cancel()
        startEventForwarding()

        let vocabulary = VocabularyResolver.resolveFromUserDefaults(context: modelContext)

        do {
            try await client.connect(
                apiKey: apiKey,
                model: model.name,
                language: language,
                customVocabulary: vocabulary,
                endpointingMs: XAISettings.endpointingMs,
                fillerWords: XAISettings.keepFillerWords,
                diarize: nil
            )
        } catch {
            forwardingTask?.cancel()
            forwardingTask = nil
            throw mapError(error)
        }
    }

    func sendAudioChunk(_ data: Data) async throws {
        do {
            try await client.sendAudioChunk(data)
        } catch {
            throw mapError(error)
        }
    }

    func commit() async throws {
        do {
            try await client.commit()
        } catch {
            throw mapError(error)
        }
    }

    func disconnect() async {
        forwardingTask?.cancel()
        forwardingTask = nil
        await client.disconnect()
        eventsContinuation?.finish()
    }

    // MARK: - Private

    private func startEventForwarding() {
        forwardingTask = Task { [weak self] in
            guard let self else { return }
            for await event in self.client.transcriptionEvents {
                switch event {
                case .sessionStarted:
                    self.eventsContinuation?.yield(.sessionStarted)
                case .partial(let text):
                    self.eventsContinuation?.yield(.partial(text: text))
                case .committed(let text):
                    self.eventsContinuation?.yield(.committed(text: text))
                case .error(let message):
                    self.eventsContinuation?.yield(.error(StreamingTranscriptionError.serverError(message)))
                }
            }
        }
    }

    private func mapError(_ error: Error) -> Error {
        guard let llmError = error as? LLMKitError else { return error }
        switch llmError {
        case .missingAPIKey:
            return StreamingTranscriptionError.missingAPIKey
        case .httpError(_, let message):
            return StreamingTranscriptionError.serverError(message)
        case .networkError(let detail):
            return StreamingTranscriptionError.connectionFailed(detail)
        default:
            return StreamingTranscriptionError.serverError(llmError.localizedDescription ?? "Unknown error")
        }
    }
}

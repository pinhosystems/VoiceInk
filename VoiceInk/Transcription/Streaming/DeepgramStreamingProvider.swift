import Foundation
import SwiftData
import LLMkit
import os

/// Deepgram streaming provider wrapping `LLMkit.DeepgramStreamingClient`.
final class DeepgramStreamingProvider: StreamingTranscriptionProvider {

    /// Deepgram's `keyterm` query parameter has a documented cap. We trim
    /// the user's vocabulary to this many entries before sending; anything
    /// beyond gets logged and surfaced to the user as a one-shot warning.
    private static let maxKeytermCount = 50

    /// `true` once we've shown the truncation warning notification this
    /// process; prevents spamming the user on every recording when their
    /// dictionary exceeds the cap.
    private static let warnedAboutTruncation = OSAllocatedUnfairLock<Bool>(initialState: false)

    private static let logger = Logger(
        subsystem: "com.prakashjoshipax.voiceink",
        category: "DeepgramStreamingProvider"
    )

    private let client = LLMkit.DeepgramStreamingClient()
    private var eventsContinuation: AsyncStream<StreamingTranscriptionEvent>.Continuation?
    private var forwardingTask: Task<Void, Never>?
    private let modelContext: ModelContext

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
        guard let apiKey = APIKeyManager.shared.getAPIKey(forProvider: "Deepgram"), !apiKey.isEmpty else {
            throw StreamingTranscriptionError.missingAPIKey
        }

        let vocabulary = getCustomVocabularyTerms()

        // Cancel any existing forwarding task before starting a new one
        forwardingTask?.cancel()
        startEventForwarding()

        do {
            try await client.connect(apiKey: apiKey, model: model.name, language: language, customVocabulary: vocabulary)
        } catch {
            // Clean up forwarding task on connection failure
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

    private func getCustomVocabularyTerms() -> [String] {
        let descriptor = FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\.word)])
        guard let vocabularyWords = try? modelContext.fetch(descriptor) else {
            return []
        }
        var seen = Set<String>()
        var unique: [String] = []
        for word in vocabularyWords {
            let trimmed = word.word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(trimmed)
            }
        }

        if unique.count > Self.maxKeytermCount {
            Self.logger.warning("Deepgram custom vocabulary truncated: \(unique.count, privacy: .public) configured → \(Self.maxKeytermCount, privacy: .public) sent (alphabetical order)")
            let shouldNotify = Self.warnedAboutTruncation.withLock { hasWarned -> Bool in
                let firstTime = !hasWarned
                hasWarned = true
                return firstTime
            }
            if shouldNotify {
                let configuredCount = unique.count
                Task { @MainActor in
                    NotificationManager.shared.showNotification(
                        title: "Deepgram uses only the first \(Self.maxKeytermCount) of your \(configuredCount) vocabulary terms",
                        type: .warning,
                        duration: 6.0
                    )
                }
            }
            return Array(unique.prefix(Self.maxKeytermCount))
        }
        return unique
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

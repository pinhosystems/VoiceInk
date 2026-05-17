import Foundation
import AVFoundation
import os

/// Encapsulates a single recording-to-transcription lifecycle (streaming or file-based).
@MainActor
protocol TranscriptionSession: AnyObject {
    /// Prepares the session. Returns an audio chunk callback for streaming, or nil for file-based.
    func prepare(model: any TranscriptionModel) async throws -> ((Data) -> Void)?

    /// Called after recording stops. Returns the final transcribed text.
    func transcribe(audioURL: URL) async throws -> String

    /// Cancel the session and clean up resources.
    func cancel()
}

// MARK: - File-Based Session

/// File-based session: records to file, uploads after stop.
@MainActor
final class FileTranscriptionSession: TranscriptionSession {
    private let service: TranscriptionService
    private var model: (any TranscriptionModel)?

    init(service: TranscriptionService) {
        self.service = service
    }

    func prepare(model: any TranscriptionModel) async throws -> ((Data) -> Void)? {
        self.model = model
        return nil
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard let model = model else {
            throw VoiceInkEngineError.transcriptionFailed
        }
        return try await service.transcribe(audioURL: audioURL, model: model)
    }

    func cancel() {
        // No-op for file-based transcription
    }
}

// MARK: - Streaming Session

/// Streaming session with automatic fallback to file-based upload on failure.
@MainActor
final class StreamingTranscriptionSession: TranscriptionSession {
    private let streamingService: StreamingTranscriptionService
    private let fallbackService: TranscriptionService
    private var model: (any TranscriptionModel)?
    private var streamingFailed = false
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "StreamingTranscriptionSession")

    init(streamingService: StreamingTranscriptionService, fallbackService: TranscriptionService) {
        self.streamingService = streamingService
        self.fallbackService = fallbackService
    }

    func prepare(model: any TranscriptionModel) async throws -> ((Data) -> Void)? {
        self.model = model
        logger.notice("Streaming session prepare model=\(model.displayName, privacy: .public)")

        // Return callback immediately; WebSocket connects in background
        let service = streamingService
        let callback: (Data) -> Void = { [weak service] data in
            service?.sendAudioChunk(data)
        }

        Task { [weak self] in
            guard let self = self else { return }
            do {
                let start = Date()
                try await self.streamingService.startStreaming(model: model)
                self.logger.notice("Streaming session connected model=\(model.displayName, privacy: .public) elapsed=\(Date().timeIntervalSince(start), format: .fixed(precision: 3), privacy: .public)s")
            } catch {
                let desc = error.localizedDescription
                self.logger.error("❌ Failed to start streaming, will fall back to batch: \(desc, privacy: .public)")
                self.streamingFailed = true
            }
        }

        return callback
    }

    func transcribe(audioURL: URL) async throws -> String {
        guard let model = model else {
            throw VoiceInkEngineError.transcriptionFailed
        }

        if !streamingFailed {
            do {
                let start = Date()
                logger.notice("Streaming stop/transcribe started model=\(model.displayName, privacy: .public)")
                let text = try await streamingService.stopAndGetFinalText()
                logger.notice("Streaming transcript received elapsed=\(Date().timeIntervalSince(start), format: .fixed(precision: 3), privacy: .public)s chars=\(text.count, privacy: .public)")
                if await Self.isSuspiciouslyShort(text: text, audioURL: audioURL) {
                    logger.warning("Streaming result suspiciously short for audio duration — falling back to batch to verify")
                    streamingService.cancel()
                } else {
                    return text
                }
            } catch {
                logger.error("❌ Streaming failed, falling back to batch: \(error.localizedDescription, privacy: .public)")
                streamingService.cancel()
            }
        } else {
            streamingService.cancel()
        }

        let fallbackStart = Date()
        logger.notice("Using batch fallback for \(model.displayName, privacy: .public) file=\(audioURL.lastPathComponent, privacy: .public)")
        let text = try await fallbackService.transcribe(audioURL: audioURL, model: model)
        logger.notice("Batch fallback completed elapsed=\(Date().timeIntervalSince(fallbackStart), format: .fixed(precision: 3), privacy: .public)s chars=\(text.count, privacy: .public)")

        // If the batch result is *also* suspiciously short, the upstream STT
        // service is degrading (we have seen this with xAI Grok returning
        // ~25 chars for ~12s clips on both streaming and batch paths).
        // Streaming → batch fallback can't fix that — surface a visible warning
        // so the user knows to retry with a different provider instead of
        // silently accepting the truncated text.
        if await Self.isSuspiciouslyShort(text: text, audioURL: audioURL) {
            logger.warning("Batch fallback result also suspiciously short — surfacing notification")
            await MainActor.run {
                NotificationManager.shared.showNotification(
                    title: "Transcription appears incomplete from \(model.displayName) — consider retrying with a different model",
                    type: .warning,
                    duration: 7.0
                )
            }
        }
        return text
    }

    /// Defensive heuristic: streaming providers (and occasionally the matching
    /// batch endpoint) return a successful but truncated transcript when the
    /// upstream service degrades. If the resulting text is too short relative
    /// to the recorded audio duration, retry through the batch endpoint to
    /// verify (and recover) the full transcription.
    ///
    /// Thresholds — kept conservative to avoid false positives on silent or
    /// very short clips, but tuned high enough to catch the xAI failure mode
    /// observed in production (29.8s audio → 209 chars = 7 chars/s):
    ///   - Only triggers when audio duration ≥ 8 seconds.
    ///   - Triggers when transcript yields fewer than 8 chars/second of audio.
    /// Normal Portuguese / Spanish / English speech rates are ~12–17 chars/s.
    /// 8 chars/s leaves room for slow speakers or pauses but is well below any
    /// realistic rate for continuous dictation. The previous value (5 chars/s)
    /// missed mid-degradation cases like the one above.
    private static let suspiciouslyShortCharsPerSecond: Double = 8.0
    private static let suspiciouslyShortMinDuration: Double = 8.0

    private static func isSuspiciouslyShort(text: String, audioURL: URL) async -> Bool {
        let asset = AVURLAsset(url: audioURL)
        guard let cmDuration = try? await asset.load(.duration) else { return false }
        let duration = CMTimeGetSeconds(cmDuration)
        guard duration.isFinite, duration >= suspiciouslyShortMinDuration else { return false }
        let charsPerSecond = Double(text.count) / duration
        return charsPerSecond < suspiciouslyShortCharsPerSecond
    }

    func cancel() {
        streamingService.cancel()
    }
}

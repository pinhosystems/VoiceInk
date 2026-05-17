import Foundation
import AVFoundation
import os

/// Detects transcripts that look truncated relative to the audio they came from.
///
/// Background: cloud STT providers can return a successful response that is
/// silently truncated when the upstream service is degrading. We saw this with
/// xAI Grok in production: 29.8s of continuous Portuguese came back as 209
/// chars (~7 chars/s) on both the streaming and batch endpoints, with no
/// error surfaced anywhere — the user only noticed by re-reading the result.
///
/// Normal speech in Portuguese / Spanish / English is ~12–17 chars/s.
/// 8 chars/s leaves room for slow speakers and natural pauses while still
/// catching mid-degradation cases. The 8-second minimum duration avoids
/// false positives on very short utterances ("ok", "yes") where char/s is
/// inherently noisy.
enum TranscriptionResultValidator {

    /// Below this rate the transcript is treated as suspiciously short.
    static let charsPerSecondThreshold: Double = 8.0

    /// Only run the check on clips at least this long; shorter clips have
    /// too few characters for the ratio to mean anything.
    static let minimumDurationSeconds: Double = 8.0

    /// Returns true when the transcript is too short for the audio duration
    /// to be plausible continuous speech.
    static func isSuspiciouslyShort(text: String, audioURL: URL) async -> Bool {
        let asset = AVURLAsset(url: audioURL)
        guard let cmDuration = try? await asset.load(.duration) else { return false }
        let duration = CMTimeGetSeconds(cmDuration)
        guard duration.isFinite, duration >= minimumDurationSeconds else { return false }
        let charsPerSecond = Double(text.count) / duration
        return charsPerSecond < charsPerSecondThreshold
    }

    /// Convenience: surfaces a visible warning to the user when the heuristic
    /// fires and there is no further recovery path. Intended for places (like
    /// the manual retry) where no automatic fallback can run.
    @MainActor
    static func warnIfSuspiciouslyShort(text: String, audioURL: URL, modelDisplayName: String, logger: Logger) async {
        guard await isSuspiciouslyShort(text: text, audioURL: audioURL) else { return }
        logger.warning("Transcript suspiciously short for audio duration — surfacing notification (model=\(modelDisplayName, privacy: .public))")
        NotificationManager.shared.showNotification(
            title: "Transcription appears incomplete from \(modelDisplayName) — consider retrying with a different model",
            type: .warning,
            duration: 7.0
        )
    }

    /// Runs the heuristic. If the result looks truncated, attempts to recover
    /// by re-submitting the audio in smaller chunks via the same service. The
    /// chunked result is returned **only** if it is meaningfully longer than
    /// the initial attempt — otherwise the initial attempt is kept (chunking
    /// did not help, presumably the upstream bug is content-specific rather
    /// than duration-based).
    ///
    /// - Returns: A tuple of the best text to use and a flag indicating
    ///   whether the heuristic considered the *final* text still short.
    ///   Callers should surface a notification when `stillShort` is true.
    static func attemptRecoveryIfShort(
        initial: String,
        audioURL: URL,
        model: any TranscriptionModel,
        service: TranscriptionService,
        logger: Logger
    ) async -> (text: String, stillShort: Bool) {
        guard await isSuspiciouslyShort(text: initial, audioURL: audioURL) else {
            return (initial, false)
        }
        logger.warning("Initial transcript looks truncated (chars=\(initial.count, privacy: .public)) — attempting chunked recovery")

        let chunked: String
        do {
            chunked = try await ChunkedTranscriber.transcribe(audioURL: audioURL, model: model, via: service)
        } catch {
            logger.error("Chunked recovery failed: \(error.localizedDescription, privacy: .public) — keeping original short result")
            return (initial, true)
        }

        // Only adopt the chunked result if it actually recovered something
        // beyond what we already had. 1.25× is a low bar but avoids replacing
        // a real (just slow) transcript with a chunked one that happened to
        // pick up boundary noise.
        if chunked.count > Int(Double(initial.count) * 1.25) {
            let stillShort = await isSuspiciouslyShort(text: chunked, audioURL: audioURL)
            logger.notice("Chunked recovery returned \(chunked.count, privacy: .public) chars vs \(initial.count, privacy: .public) — adopting (stillShort=\(stillShort, privacy: .public))")
            return (chunked, stillShort)
        }

        logger.warning("Chunked recovery did not improve length (initial=\(initial.count, privacy: .public), chunked=\(chunked.count, privacy: .public)) — keeping original")
        return (initial, true)
    }
}

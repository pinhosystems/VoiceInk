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

    /// Multiplier the recovered result must beat the initial result by to be
    /// adopted. 1.25× is a low bar but avoids replacing a real (just slow)
    /// transcript with a recovery attempt that happened to pick up boundary
    /// noise or coincidentally returned a similar length.
    private static let recoveryImprovementRatio: Double = 1.25

    /// Runs the heuristic. If the result looks truncated, walks a two-step
    /// recovery ladder via the same service:
    ///
    ///   1. **Retry once** with a fresh request. The most common xAI failure
    ///      mode in production is a transient `socket disconnect` mid-stream
    ///      that leaves the result short; the batch endpoint usually answers
    ///      a fresh submission correctly. Works for any audio duration
    ///      (including the 8–12 s window where chunking is a no-op).
    ///
    ///   2. **Chunked re-submission** when the retry didn't improve and the
    ///      audio is long enough to benefit from splitting (see
    ///      `ChunkedTranscriber.minimumDurationToChunk`). Helps when the
    ///      upstream bug is duration-based rather than transient.
    ///
    /// At each step, the new text is adopted only if it is meaningfully
    /// longer than the best we have so far (see `recoveryImprovementRatio`).
    /// Whatever text the ladder ends with — original, retried, or chunked —
    /// is returned along with a `stillShort` flag so callers can surface a
    /// user-visible warning when no recovery path managed to fix it.
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
        logger.warning("Initial transcript looks truncated (chars=\(initial.count, privacy: .public)) — running recovery ladder")

        var best = initial
        let initialThreshold = Int(Double(initial.count) * recoveryImprovementRatio)

        // Step 1: retry once. Cheap (~1–2s) and covers the common transient
        // failure that no amount of chunking would address.
        do {
            let retried = try await service.transcribe(audioURL: audioURL, model: model)
            if retried.count > initialThreshold {
                logger.notice("Same-provider retry recovered \(retried.count, privacy: .public) chars vs \(initial.count, privacy: .public) — adopting")
                best = retried
            } else {
                logger.notice("Same-provider retry did not improve (initial=\(initial.count, privacy: .public), retried=\(retried.count, privacy: .public)) — trying chunking")
            }
        } catch {
            logger.error("Same-provider retry failed: \(error.localizedDescription, privacy: .public) — trying chunking")
        }

        // If the retry already fixed it, short-circuit the chunking attempt.
        if !(await isSuspiciouslyShort(text: best, audioURL: audioURL)) {
            return (best, false)
        }

        // Step 2: chunked re-submission. Skips internally for very short clips.
        let chunked: String
        do {
            chunked = try await ChunkedTranscriber.transcribe(audioURL: audioURL, model: model, via: service)
        } catch {
            logger.error("Chunked recovery failed: \(error.localizedDescription, privacy: .public) — keeping best so far")
            let stillShort = await isSuspiciouslyShort(text: best, audioURL: audioURL)
            return (best, stillShort)
        }

        let bestThreshold = Int(Double(best.count) * recoveryImprovementRatio)
        if chunked.count > bestThreshold {
            let stillShort = await isSuspiciouslyShort(text: chunked, audioURL: audioURL)
            logger.notice("Chunked recovery returned \(chunked.count, privacy: .public) chars vs \(best.count, privacy: .public) — adopting (stillShort=\(stillShort, privacy: .public))")
            return (chunked, stillShort)
        }

        let stillShort = await isSuspiciouslyShort(text: best, audioURL: audioURL)
        logger.warning("Chunked recovery did not improve length (best=\(best.count, privacy: .public), chunked=\(chunked.count, privacy: .public)) — keeping best (stillShort=\(stillShort, privacy: .public))")
        return (best, stillShort)
    }
}

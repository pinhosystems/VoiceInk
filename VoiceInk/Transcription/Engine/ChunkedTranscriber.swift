import Foundation
import AVFoundation
import os

/// Recovery path for cloud STT providers that silently truncate the
/// transcript of longer recordings while still returning HTTP 200.
///
/// Background: xAI Grok was observed in production returning ~50% of the
/// expected transcript on 30s clips and ~5% on 12s clips, with no error
/// surface anywhere. Both the streaming and the matching batch endpoint
/// returned the same short text, so a simple streaming → batch fallback
/// could not recover it.
///
/// This type splits the audio into smaller chunks and submits each chunk
/// independently via the same transcription service. The hypothesis is
/// that smaller payloads stay under whatever internal limit triggers the
/// truncation. If the limit is content-specific rather than duration-based,
/// chunking will not help — but the chunked result is at worst no shorter
/// than the original failing attempt and at best recovers the full audio.
///
/// Tradeoffs:
///   - **No chunk-boundary overlap**. Words split across chunk boundaries
///     may be transcribed twice (partial in each side) or missed once.
///     Tolerable for a fallback that only runs when the normal path
///     already produced a short result.
///   - **Sequential submission**. Parallel would be faster but risks the
///     provider's rate limit. Sequential keeps the recovery predictable.
///   - **Latency scales with chunk count**. A 30s clip with the default
///     10s chunks becomes ~3 sequential requests.
enum ChunkedTranscriber {

    /// Length of each chunk. 10s is short enough to stay under most observed
    /// provider truncation points while long enough that boundary artifacts
    /// stay rare.
    static let chunkDurationSeconds: Double = 10.0

    /// Don't bother chunking audio below this duration — a single chunk equal
    /// to the whole file is pointless, and very short clips usually fail for
    /// content reasons rather than duration.
    static let minimumDurationToChunk: Double = 12.0

    private static let logger = Logger(
        subsystem: "com.prakashjoshipax.voiceink",
        category: "ChunkedTranscriber"
    )

    /// Submits the audio to `service` in sequential chunks and concatenates
    /// the returned text. Throws if any chunk fails (the caller should keep
    /// its previous, suspiciously-short, result and surface a warning).
    static func transcribe(
        audioURL: URL,
        model: any TranscriptionModel,
        via service: TranscriptionService
    ) async throws -> String {
        let inputFile = try AVAudioFile(forReading: audioURL)
        let sampleRate = inputFile.fileFormat.sampleRate
        let totalFrames = inputFile.length
        let totalSeconds = Double(totalFrames) / sampleRate

        guard totalSeconds >= minimumDurationToChunk else {
            logger.notice("Skipping chunking — audio too short (\(totalSeconds, format: .fixed(precision: 1), privacy: .public)s < \(minimumDurationToChunk, format: .fixed(precision: 1), privacy: .public)s)")
            // Fall back to a single submission — same as caller would have done.
            return try await service.transcribe(audioURL: audioURL, model: model)
        }

        let chunkFrameCount = AVAudioFrameCount(chunkDurationSeconds * sampleRate)
        var startFrame: AVAudioFramePosition = 0
        var chunkIndex = 0
        var parts: [String] = []

        let expectedChunks = Int(ceil(totalSeconds / chunkDurationSeconds))
        logger.notice("Chunking \(totalSeconds, format: .fixed(precision: 1), privacy: .public)s audio into \(expectedChunks, privacy: .public) chunks of \(chunkDurationSeconds, format: .fixed(precision: 1), privacy: .public)s each")

        let tempBase = FileManager.default.temporaryDirectory

        while startFrame < totalFrames {
            let framesLeft = AVAudioFrameCount(totalFrames - startFrame)
            let framesThisChunk = min(framesLeft, chunkFrameCount)
            let chunkURL = tempBase.appendingPathComponent("voiceink-chunk-\(UUID().uuidString).wav")

            do {
                try writeChunk(
                    from: inputFile,
                    startFrame: startFrame,
                    frameCount: framesThisChunk,
                    to: chunkURL
                )
            } catch {
                try? FileManager.default.removeItem(at: chunkURL)
                logger.error("Failed to write chunk \(chunkIndex, privacy: .public): \(error.localizedDescription, privacy: .public)")
                throw error
            }

            do {
                let text = try await service.transcribe(audioURL: chunkURL, model: model)
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    parts.append(trimmed)
                }
                logger.notice("Chunk \(chunkIndex, privacy: .public)/\(expectedChunks, privacy: .public) returned \(trimmed.count, privacy: .public) chars")
            } catch {
                try? FileManager.default.removeItem(at: chunkURL)
                logger.error("Chunk \(chunkIndex, privacy: .public)/\(expectedChunks, privacy: .public) failed: \(error.localizedDescription, privacy: .public)")
                throw error
            }

            try? FileManager.default.removeItem(at: chunkURL)
            startFrame += AVAudioFramePosition(framesThisChunk)
            chunkIndex += 1
        }

        let joined = parts.joined(separator: " ")
        logger.notice("Chunked transcription complete: \(parts.count, privacy: .public) chunks, totalChars=\(joined.count, privacy: .public)")
        return joined
    }

    private static func writeChunk(
        from source: AVAudioFile,
        startFrame: AVAudioFramePosition,
        frameCount: AVAudioFrameCount,
        to outputURL: URL
    ) throws {
        let processingFormat = source.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: frameCount) else {
            throw NSError(
                domain: "ChunkedTranscriber",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to allocate PCM buffer for chunk"]
            )
        }
        source.framePosition = startFrame
        try source.read(into: buffer, frameCount: frameCount)

        // Write to disk in the same on-disk format as the source (typically
        // 16-bit PCM 16 kHz mono for VoiceInk's own recordings).
        // AVAudioFile handles the conversion from the in-memory processing
        // format (Float32) to the on-disk format during write.
        let outputFile = try AVAudioFile(
            forWriting: outputURL,
            settings: source.fileFormat.settings
        )
        try outputFile.write(from: buffer)
    }
}

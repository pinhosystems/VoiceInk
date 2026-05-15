import Foundation
import AVFoundation
import os

class WhisperTranscriptionService: TranscriptionService {

    private var whisperContext: WhisperContext?
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "WhisperTranscriptionService")
    private let modelsDirectory: URL
    private weak var modelProvider: (any WhisperModelProvider)?

    init(modelsDirectory: URL, modelProvider: (any WhisperModelProvider)? = nil) {
        self.modelsDirectory = modelsDirectory
        self.modelProvider = modelProvider
    }

    func transcribe(audioURL: URL, model: any TranscriptionModel) async throws -> String {
        guard model.provider == .whisper else {
            throw VoiceInkEngineError.modelLoadFailed
        }

        logger.notice("Initiating local transcription for model: \(model.displayName, privacy: .public)")

        // Check if the required model is already loaded in the model provider
        if let provider = modelProvider,
           await provider.isModelLoaded,
           let loadedContext = await provider.whisperContext,
           await provider.loadedWhisperModel?.name == model.name {

            logger.notice("Using already loaded model: \(model.name, privacy: .public)")
            whisperContext = loadedContext
        } else {
            // Resolve the on-disk URL using the provider's availableModels (covers imports)
            let resolvedURL: URL? = await modelProvider?.availableModels.first(where: { $0.name == model.name })?.url
            guard let modelURL = resolvedURL, FileManager.default.fileExists(atPath: modelURL.path) else {
                logger.error("❌ Model file not found for: \(model.name, privacy: .public)")
                throw VoiceInkEngineError.modelLoadFailed
            }

            logger.notice("Loading model: \(model.name, privacy: .public)")
            do {
                whisperContext = try await WhisperContext.createContext(path: modelURL.path)
            } catch {
                logger.error("❌ Failed to load model: \(model.name, privacy: .public) - \(error.localizedDescription, privacy: .public)")
                throw VoiceInkEngineError.modelLoadFailed
            }
        }

        guard let whisperContext = whisperContext else {
            logger.error("❌ Cannot transcribe: Model could not be loaded")
            throw VoiceInkEngineError.modelLoadFailed
        }

        // Read audio data
        let data = try readAudioSamples(audioURL)

        // Set prompt
        let currentPrompt = UserDefaults.standard.string(forKey: "TranscriptionPrompt") ?? ""
        await whisperContext.setPrompt(currentPrompt)

        // Transcribe
        let success = await whisperContext.fullTranscribe(samples: data)

        guard success else {
            logger.error("❌ Core transcription engine failed (whisper_full).")
            throw VoiceInkEngineError.whisperCoreFailed
        }

        let text = await whisperContext.getTranscription()

        logger.notice("Whisper transcription completed successfully.")

        // Only release resources if we created a new context (not using the shared one)
        if await modelProvider?.whisperContext !== whisperContext {
            await whisperContext.releaseResources()
            self.whisperContext = nil
        }

        return text
    }

    /// Reads PCM samples as 16 kHz mono Float32 in [-1.0, 1.0], the format Whisper expects.
    ///
    /// The previous implementation assumed a flat 44-byte WAV header and reinterpreted the
    /// remaining bytes as Int16. That works for the recorder's own output, but breaks for
    /// any imported WAV with additional chunks (LIST/INFO/bext), where the audio data
    /// starts past byte 44. AVAudioFile handles the header correctly for any sane format.
    private func readAudioSamples(_ url: URL) throws -> [Float] {
        let audioFile = try AVAudioFile(forReading: url)
        let fileFormat = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: fileFormat, frameCapacity: frameCount) else {
            return []
        }
        try audioFile.read(into: buffer)

        let target = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16_000,
            channels: 1,
            interleaved: false
        )!

        // Fast path: already 16 kHz Float32. Mix to mono if needed and return.
        if fileFormat.sampleRate == target.sampleRate,
           fileFormat.commonFormat == .pcmFormatFloat32 {
            return Self.flattenFloat32Mono(buffer)
        }

        guard let converter = AVAudioConverter(from: fileFormat, to: target) else {
            throw VoiceInkEngineError.modelLoadFailed
        }
        let ratio = target.sampleRate / fileFormat.sampleRate
        let outFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 1024
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: outFrameCapacity) else {
            throw VoiceInkEngineError.modelLoadFailed
        }

        var fed = false
        var conversionError: NSError?
        converter.convert(to: outBuffer, error: &conversionError) { _, status in
            if fed {
                status.pointee = .endOfStream
                return nil
            }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        if let conversionError {
            throw conversionError
        }
        return Self.flattenFloat32Mono(outBuffer)
    }

    private static func flattenFloat32Mono(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        if channelCount == 1 {
            return Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        }
        var out = [Float](repeating: 0, count: frameLength)
        let invChannels = 1.0 / Float(channelCount)
        for frame in 0..<frameLength {
            var sum: Float = 0
            for channel in 0..<channelCount {
                sum += channelData[channel][frame]
            }
            out[frame] = sum * invChannels
        }
        return out
    }
}

import Foundation
import SwiftUI
import AVFoundation
import SwiftData
import os

@MainActor
class AudioTranscriptionService: ObservableObject {
    @Published var isTranscribing = false
    @Published var currentError: TranscriptionError?

    private let modelContext: ModelContext
    private let enhancementService: AIEnhancementService?
    private let logger = Logger(subsystem: "agabo.dev.voiceink", category: "AudioTranscriptionService")
    private let serviceRegistry: TranscriptionServiceRegistry

    enum TranscriptionError: Error {
        case noAudioFile
        case transcriptionFailed
        case modelNotLoaded
        case invalidAudioFormat
    }

    init(modelContext: ModelContext, engine: VoiceInkEngine) {
        self.modelContext = modelContext
        self.enhancementService = engine.enhancementService
        self.serviceRegistry = TranscriptionServiceRegistry(modelProvider: engine.whisperModelManager, modelsDirectory: engine.whisperModelManager.modelsDirectory, modelContext: modelContext)
    }

    init(modelContext: ModelContext, serviceRegistry: TranscriptionServiceRegistry, enhancementService: AIEnhancementService?) {
        self.modelContext = modelContext
        self.enhancementService = enhancementService
        self.serviceRegistry = serviceRegistry
    }
    
    func retranscribeAudio(from url: URL, using model: any TranscriptionModel) async throws -> Transcription {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw TranscriptionError.noAudioFile
        }
        
        await MainActor.run {
            isTranscribing = true
        }
        
        var apiLog = APICallLog()

        do {
            let transcriptionStart = Date()
            var text = try await serviceRegistry.transcribe(audioURL: url, model: model)
            let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)
            text = TranscriptionOutputFilter.filter(text)
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)

            apiLog.steps.append(Self.makeSTTStep(
                model: model,
                language: LanguageResolver.effectiveSTTCode(for: model),
                durationMs: Int(transcriptionDuration * 1000),
                response: text,
                error: nil
            ))

            let powerModeManager = PowerModeManager.shared
            let activePowerModeConfig = powerModeManager.currentActiveConfiguration
            let powerModeName = activePowerModeConfig?.name
            let powerModeEmoji = activePowerModeConfig?.emoji

            if UserDefaults.standard.bool(forKey: "IsTextFormattingEnabled") {
                text = WhisperTextFormatter.format(text)
            }

            text = WordReplacementService.shared.applyReplacements(to: text, using: modelContext)
            logger.notice("✅ Word replacements applied")
            let cleanedText = TranscriptionOutputFilter.applyUserCleanupPreferences(text)

            let audioAsset = AVURLAsset(url: url)
            let duration = CMTimeGetSeconds(try await audioAsset.load(.duration))
            let recordingsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("agabo.dev.voiceink")
                .appendingPathComponent("Recordings")
            
            let fileName = "retranscribed_\(UUID().uuidString).wav"
            let permanentURL = recordingsDirectory.appendingPathComponent(fileName)
            
            do {
                try FileManager.default.copyItem(at: url, to: permanentURL)
            } catch {
                logger.error("❌ Failed to create permanent copy of audio: \(error.localizedDescription, privacy: .public)")
                isTranscribing = false
                throw error
            }
            
            let permanentURLString = permanentURL.absoluteString

            // Retry path: skip trigger-word prompt detection so the LLM call
            // honours the user's *current* profile. The detection service is
            // for hands-free first-pass dictation ("hey assistant, do X") —
            // when the user clicks Retry in History they have already picked
            // a model and profile in the UI; re-running detection on the
            // same audio would silently override that choice (e.g. with the
            // Assistant prompt that triggered the original run).
            let originalText = cleanedText

            // Apply AI enhancement if enabled
            if let enhancementService = enhancementService,
               enhancementService.isEnhancementEnabled,
               enhancementService.isConfigured {
                do {
                    let textForAI = text
                    let (enhancedText, enhancementDuration, promptName) = try await enhancementService.enhance(textForAI)
                    if let llmStep = enhancementService.lastLLMCallStep {
                        apiLog.steps.append(llmStep)
                    }
                    let newTranscription = Transcription(
                        text: originalText,
                        duration: duration,
                        enhancedText: enhancedText,
                        audioFileURL: permanentURLString,
                        transcriptionModelName: model.displayName,
                        aiEnhancementModelName: enhancementService.getAIService()?.currentModel,
                        promptName: promptName,
                        transcriptionDuration: transcriptionDuration,
                        enhancementDuration: enhancementDuration,
                        powerModeName: powerModeName,
                        powerModeEmoji: powerModeEmoji,
                        troubleshootingLogJSON: apiLog.encoded()
                    )
                    modelContext.insert(newTranscription)
                    do {
                        try modelContext.save()
                        NotificationCenter.default.post(name: .transcriptionCreated, object: newTranscription)
                        NotificationCenter.default.post(name: .transcriptionCompleted, object: newTranscription)
                    } catch {
                        logger.error("❌ Failed to save transcription: \(error.localizedDescription, privacy: .public)")
                    }

                    await MainActor.run {
                        isTranscribing = false
                    }

                    return newTranscription
                } catch {
                    if let llmStep = enhancementService.lastLLMCallStep {
                        apiLog.steps.append(llmStep)
                    }
                    let newTranscription = Transcription(
                        text: originalText,
                        duration: duration,
                        audioFileURL: permanentURLString,
                        transcriptionModelName: model.displayName,
                        promptName: nil,
                        transcriptionDuration: transcriptionDuration,
                        powerModeName: powerModeName,
                        powerModeEmoji: powerModeEmoji,
                        troubleshootingLogJSON: apiLog.encoded()
                    )
                    modelContext.insert(newTranscription)
                    do {
                        try modelContext.save()
                        NotificationCenter.default.post(name: .transcriptionCreated, object: newTranscription)
                        NotificationCenter.default.post(name: .transcriptionCompleted, object: newTranscription)
                    } catch {
                        logger.error("❌ Failed to save transcription: \(error.localizedDescription, privacy: .public)")
                    }

                    await MainActor.run {
                        isTranscribing = false
                    }

                    return newTranscription
                }
            } else {
                let newTranscription = Transcription(
                    text: originalText,
                    duration: duration,
                    audioFileURL: permanentURLString,
                    transcriptionModelName: model.displayName,
                    promptName: nil,
                    transcriptionDuration: transcriptionDuration,
                    powerModeName: powerModeName,
                    powerModeEmoji: powerModeEmoji,
                    troubleshootingLogJSON: apiLog.encoded()
                )
                modelContext.insert(newTranscription)
                do {
                    try modelContext.save()
                    NotificationCenter.default.post(name: .transcriptionCompleted, object: newTranscription)
                } catch {
                    logger.error("❌ Failed to save transcription: \(error.localizedDescription, privacy: .public)")
                }

                await MainActor.run {
                    isTranscribing = false
                }

                return newTranscription
            }
        } catch {
            logger.error("❌ Transcription failed: \(error.localizedDescription, privacy: .public)")
            currentError = .transcriptionFailed
            isTranscribing = false
            throw error
        }
    }

    /// Builds the STT entry attached to a retried transcription's
    /// troubleshooting fixture. Mirrors `TranscriptionPipeline.makeSTTStep`
    /// — kept as a static to avoid coupling AudioTranscriptionService to
    /// the pipeline.
    static func makeSTTStep(
        model: any TranscriptionModel,
        language: String?,
        durationMs: Int,
        response: String?,
        error: String?
    ) -> APICallLog.Step {
        let isLocal = model.provider == .whisper
            || model.provider == .fluidAudio
            || model.provider == .nativeApple
        return APICallLog.Step(
            kind: .stt,
            provider: model.provider.rawValue,
            providerVariant: isLocal ? "Local" : "Cloud",
            endpointHost: isLocal ? nil : CloudProviderRegistry.provider(for: model.provider)?.providerKey,
            model: model.name,
            languageCode: language,
            requestSummary: "audio bytes (\(durationMs)ms transcription)",
            requestSystemMessage: nil,
            requestUserMessage: nil,
            responseSummary: response,
            durationMs: durationMs,
            errorMessage: error
        )
    }
}

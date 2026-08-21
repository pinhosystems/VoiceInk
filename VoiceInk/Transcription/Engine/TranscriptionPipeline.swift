import Foundation
import AppKit
import AVFoundation
import SwiftData
import os

/// Handles the full post-recording pipeline:
/// transcribe → filter → format → word-replace → prompt-detect → AI enhance → start paste + dismiss → save
@MainActor
class TranscriptionPipeline {
    private let modelContext: ModelContext
    private let serviceRegistry: TranscriptionServiceRegistry
    private let enhancementService: AIEnhancementService?
    private let promptDetectionService = PromptDetectionService()
    private let logger = Logger(subsystem: "agabo.dev.voiceink", category: "TranscriptionPipeline")

    init(
        modelContext: ModelContext,
        serviceRegistry: TranscriptionServiceRegistry,
        enhancementService: AIEnhancementService?
    ) {
        self.modelContext = modelContext
        self.serviceRegistry = serviceRegistry
        self.enhancementService = enhancementService
    }

    /// Run the full pipeline for a given transcription record.
    /// - Parameters:
    ///   - transcription: The pending Transcription SwiftData object to populate and save.
    ///   - audioURL: The recorded audio file.
    ///   - model: The transcription model to use.
    ///   - session: An active streaming session if one was prepared, otherwise nil.
    ///   - onStateChange: Called when the pipeline moves to a new recording state (e.g. `.enhancing`).
    ///   - shouldCancel: Returns true if the user requested cancellation.
    ///   - onCleanup: Called when cancellation is detected to release model resources.
    ///   - onDismiss: Called as soon as paste is initiated to dismiss the recorder panel.
    func run(
        transcription: Transcription,
        audioURL: URL,
        model: any TranscriptionModel,
        session: TranscriptionSession?,
        onStateChange: @escaping (RecordingState) -> Void,
        shouldCancel: () -> Bool,
        onCleanup: @escaping () async -> Void,
        onDismiss: @escaping () async -> Void
    ) async {
        if shouldCancel() {
            await onCleanup()
            return
        }

        var finalPastedText: String?
        var promptDetectionResult: PromptDetectionService.PromptDetectionResult?
        var didInsertSessionMetric = false
        var agenticDecision: AgenticDecision?
        var agenticOriginalPromptId: UUID?
        var agenticOriginalEnhancementEnabled: Bool?
        var agenticPrevOutputLanguage: String?
        var agenticDidSetOutputLanguage = false

        do {
            let transcriptionStart = Date()
            var text: String
            if let session {
                text = try await session.transcribe(audioURL: audioURL)
            } else {
                text = try await serviceRegistry.transcribe(audioURL: audioURL, model: model)
            }
            text = TranscriptionOutputFilter.filter(text)
            let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)

            let powerModeManager = PowerModeManager.shared
            let activePowerModeConfig = powerModeManager.currentActiveConfiguration
            let powerModeName = activePowerModeConfig?.name
            let powerModeEmoji = activePowerModeConfig?.emoji

            if shouldCancel() { await onCleanup(); return }

            text = text.trimmingCharacters(in: .whitespacesAndNewlines)

            if UserDefaults.standard.bool(forKey: "IsTextFormattingEnabled") {
                text = WhisperTextFormatter.format(text)
            }

            text = WordReplacementService.shared.applyReplacements(to: text, using: modelContext)

            // Locale-aware normalization. The resolved `LocalePack` decides what
            // runs: `BrazilianPortuguesePack.customNormalize` delegates to the
            // existing Brazilian transforms (CPF, CNPJ, CEP, phones, hours,
            // percent, decimals, currency in reais); other curated packs add
            // their own rules; the generic Portuguese fallback ships none.
            // Placed BEFORE the user-cleanup step so the LLM enhancement and
            // final output both see well-formed identifiers and currency.
            let selectedLanguage = LanguageResolver.effectiveSTTCode()
            if let pack = LocalePackRegistry.pack(for: selectedLanguage),
               LocalePackRegistry.normalizationEnabled {
                text = LocaleNormalizer.apply(text, pack: pack)
            }

            let cleanedText = TranscriptionOutputFilter.applyUserCleanupPreferences(text)

            let audioAsset = AVURLAsset(url: audioURL)
            let actualDuration = (try? CMTimeGetSeconds(await audioAsset.load(.duration))) ?? 0.0

            transcription.text = cleanedText
            transcription.duration = actualDuration
            transcription.transcriptionModelName = model.displayName
            transcription.transcriptionDuration = transcriptionDuration
            transcription.powerModeName = powerModeName
            transcription.powerModeEmoji = powerModeEmoji
            finalPastedText = cleanedText

            var apiLog = APICallLog()
            apiLog.steps.append(makeSTTStep(
                model: model,
                language: selectedLanguage,
                durationMs: Int(transcriptionDuration * 1000),
                response: cleanedText,
                error: nil
            ))

            // Agentic router: interprets spoken meta-directives ("isso aqui
            // é um email formal") and reconfigures the run. When it acts,
            // deterministic trigger-word detection is skipped; when it
            // abstains or fails, the pipeline behaves exactly as before.
            if let enhancementService, enhancementService.isConfigured,
               AgenticSettings.isEnabled,
               let aiService = enhancementService.getAIService() {
                let outcome = await AgenticRouterService.route(
                    text: text,
                    enhancementService: enhancementService,
                    aiService: aiService
                )
                apiLog.steps.append(outcome.logStep)
                let decision = outcome.decision
                if decision.hasActions {
                    agenticDecision = decision
                    if let promptId = decision.promptId {
                        agenticOriginalPromptId = enhancementService.selectedPromptId
                        agenticOriginalEnhancementEnabled = enhancementService.isEnhancementEnabled
                        enhancementService.selectedPromptId = promptId
                        enhancementService.isEnhancementEnabled = true
                    }
                    if decision.clearProfile {
                        PowerModeManager.shared.setActiveConfiguration(nil)
                        await PowerModeSessionManager.shared.endSession()
                    } else if let profileId = decision.profileId,
                              let config = PowerModeManager.shared.getConfiguration(with: profileId) {
                        PowerModeManager.shared.setActiveConfiguration(config)
                        await PowerModeSessionManager.shared.beginSession(with: config)
                    }
                    if let language = decision.outputLanguage {
                        agenticPrevOutputLanguage = UserDefaults.standard.string(forKey: LocalePackRegistry.outputLanguageKey)
                        agenticDidSetOutputLanguage = true
                        UserDefaults.standard.set(language, forKey: LocalePackRegistry.outputLanguageKey)
                    }
                }
            }

            if agenticDecision == nil, let enhancementService, enhancementService.isConfigured {
                let detectionResult = await promptDetectionService.analyzeText(text, with: enhancementService)
                promptDetectionResult = detectionResult
                await promptDetectionService.applyDetectionResult(detectionResult, to: enhancementService)
            }

            let isSkipShortEnhancementEnabled = UserDefaults.standard.bool(forKey: "SkipShortEnhancement")
            let savedThreshold = UserDefaults.standard.integer(forKey: "ShortEnhancementWordThreshold")
            let shortEnhancementWordThreshold = savedThreshold > 0 ? savedThreshold : 3
            let shouldSkipEnhancement = isSkipShortEnhancementEnabled && WordCounter.count(in: text) <= shortEnhancementWordThreshold && !(promptDetectionResult?.shouldEnableAI == true) && agenticDecision?.promptId == nil

            if let enhancementService,
               enhancementService.isEnhancementEnabled,
               enhancementService.isConfigured,
               !shouldSkipEnhancement {
                if shouldCancel() { await onCleanup(); return }

                onStateChange(.enhancing)
                let textForAI = agenticDecision?.cleanedText ?? promptDetectionResult?.processedText ?? text

                do {
                    let (enhancedText, enhancementDuration, promptName) = try await enhancementService.enhance(textForAI)
                    transcription.enhancedText = enhancedText
                    transcription.aiEnhancementModelName = enhancementService.getAIService()?.currentModel
                    transcription.promptName = promptName
                    transcription.enhancementDuration = enhancementDuration
                    if let llmStep = enhancementService.lastLLMCallStep {
                        apiLog.steps.append(llmStep)
                    }
                    finalPastedText = enhancedText
                } catch {
                    let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    transcription.enhancedText = "Enhancement failed: \(errorDescription)"
                    if let llmStep = enhancementService.lastLLMCallStep {
                        apiLog.steps.append(llmStep)
                    }
                    let shortReason = String(errorDescription.prefix(80))
                    await MainActor.run {
                        NotificationManager.shared.showNotification(
                            title: "Enhancement failed: \(shortReason)",
                            type: .warning
                        )
                    }
                    if shouldCancel() { await onCleanup(); return }
                }
            }

            transcription.transcriptionStatus = TranscriptionStatus.completed.rawValue
            transcription.troubleshootingLogJSON = apiLog.encoded()
        } catch {
            let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription

            if let nativeAppleError = error as? NativeAppleTranscriptionService.ServiceError,
               case .assetDownloadRequired = nativeAppleError {
                await MainActor.run {
                    NotificationManager.shared.showNotification(
                        title: errorDescription,
                        type: .error,
                        duration: 5.0
                    )
                }
            }

            // Timeouts deserve a longer, more discoverable notification: the user
            // can act on them (raise the timeout) and we don't want them to look
            // like a silent failure mixed in with the recorder dismiss animation.
            if let cloudError = error as? CloudTranscriptionError,
               case .timeout(let seconds) = cloudError {
                await MainActor.run {
                    NotificationManager.shared.showNotification(
                        title: "Transcription timed out after \(Int(seconds))s",
                        type: .error,
                        duration: 6.0
                    )
                }
            }

            transcription.text = "Transcription Failed: \(errorDescription)"
            transcription.transcriptionStatus = TranscriptionStatus.failed.rawValue
            var failureLog = APICallLog()
            failureLog.steps.append(makeSTTStep(
                model: model,
                language: LanguageResolver.effectiveSTTCode(for: model),
                durationMs: 0,
                response: nil,
                error: errorDescription
            ))
            transcription.troubleshootingLogJSON = failureLog.encoded()
        }

        func saveTranscriptionAndPostCompletion() {
            if transcription.transcriptionStatus == TranscriptionStatus.completed.rawValue {
                do {
                    didInsertSessionMetric = try SessionMetricRecorder.recordRecorderSession(
                        transcription: transcription,
                        model: model,
                        in: modelContext
                    )
                } catch {
                    logger.error("Failed to record session metric: \(error.localizedDescription, privacy: .public)")
                }
            }

            do {
                try modelContext.save()
                if didInsertSessionMetric {
                    NotificationCenter.default.post(name: .sessionMetricsDidChange, object: nil)
                }
                NotificationCenter.default.post(name: .transcriptionCompleted, object: transcription)
            } catch {
                logger.error("Failed to save transcription: \(error.localizedDescription, privacy: .public)")
            }
        }

        func restorePromptDetectionSettingsIfNeeded() async {
            if let result = promptDetectionResult,
               let enhancementService,
               result.shouldEnableAI {
                await promptDetectionService.restoreOriginalSettings(result, to: enhancementService)
            }
            // Agentic restore mirrors trigger-word restore. Profile changes
            // are session-scoped by design and never reverted here.
            if let decision = agenticDecision, decision.scope == .thisDictation {
                if decision.promptId != nil, let enhancementService {
                    if let original = agenticOriginalPromptId {
                        enhancementService.selectedPromptId = original
                    }
                    if let originalEnabled = agenticOriginalEnhancementEnabled {
                        enhancementService.isEnhancementEnabled = originalEnabled
                    }
                }
                if agenticDidSetOutputLanguage {
                    if let previous = agenticPrevOutputLanguage {
                        UserDefaults.standard.set(previous, forKey: LocalePackRegistry.outputLanguageKey)
                    } else {
                        UserDefaults.standard.removeObject(forKey: LocalePackRegistry.outputLanguageKey)
                    }
                }
            }
        }

        if shouldCancel() {
            await onCleanup()
            saveTranscriptionAndPostCompletion()
            return
        }

        if let textToPaste = finalPastedText,
           transcription.transcriptionStatus == TranscriptionStatus.completed.rawValue {
            let appendSpace = UserDefaults.standard.bool(forKey: "AppendTrailingSpace")
            let pastedText = textToPaste + (appendSpace ? " " : "")
            let delivery = agenticDecision?.delivery ?? .paste
            if delivery == .clipboardOnly {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(pastedText, forType: .string)
            } else {
                CursorPaster.startPasteAtCursor(pastedText)
            }
            let autoSendKey = agenticDecision?.autoSend ?? PowerModeManager.shared.currentActiveConfiguration?.autoSendKey
            SoundManager.shared.playStopSound()
            await restorePromptDetectionSettingsIfNeeded()

            if delivery == .paste, let autoSendKey, autoSendKey.isEnabled {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    CursorPaster.performAutoSend(autoSendKey)
                }
            }

            await onDismiss()
        } else {
            await restorePromptDetectionSettingsIfNeeded()
            await onDismiss()
        }

        saveTranscriptionAndPostCompletion()
    }

    /// Builds the STT entry that goes into `Transcription.troubleshootingLogJSON`.
    /// The endpoint host comes from `CloudProviderRegistry` when the model
    /// is cloud-backed; local models report only their provider name.
    func makeSTTStep(
        model: any TranscriptionModel,
        language: String?,
        durationMs: Int,
        response: String?,
        error: String?
    ) -> APICallLog.Step {
        let providerName = model.provider.rawValue
        let isLocal = model.provider == .whisper
            || model.provider == .fluidAudio
            || model.provider == .nativeApple
        let variant = isLocal ? "Local" : "Cloud"
        let host: String? = isLocal ? nil : CloudProviderRegistry.provider(for: model.provider).flatMap { provider in
            // Cloud providers don't expose their endpoint here; surface just
            // the providerKey so the log keeps a stable identifier without
            // leaking signed URLs.
            return provider.providerKey
        }
        return APICallLog.Step(
            kind: .stt,
            provider: providerName,
            providerVariant: variant,
            endpointHost: host,
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

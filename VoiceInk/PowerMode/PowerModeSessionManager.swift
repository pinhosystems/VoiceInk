import Foundation
import AppKit

struct ApplicationState: Codable {
    var isEnhancementEnabled: Bool
    var useScreenCaptureContext: Bool
    var selectedPromptId: String?
    var selectedAIProvider: String?
    var selectedAIModel: String?
    var selectedLanguage: String?
    var transcriptionModelName: String?
    var isTextFormattingEnabled: Bool?
    var punctuationCleanupMode: PunctuationCleanupMode?
    var removePunctuation: Bool?
    var lowercaseTranscription: Bool?
    var llmOutputLanguage: String?
    var localeNormalizationEnabled: Bool?
    var whisperPromptDomain: String?
    var removeFillerWords: Bool?
    var appendTrailingSpace: Bool?
}

struct PowerModeSession: Codable {
    let id: UUID
    let startTime: Date
    var originalState: ApplicationState
}

@MainActor
class PowerModeSessionManager {
    static let shared = PowerModeSessionManager()
    private let sessionKey = "powerModeActiveSession.v1"
    private var isApplyingPowerModeConfig = false

    private weak var stateProvider: (any PowerModeStateProvider)?
    private var enhancementService: AIEnhancementService?

    private init() {
        recoverSession()
    }

    /// Configure with new VoiceInkEngine-based provider.
    func configure(engine: any PowerModeStateProvider, enhancementService: AIEnhancementService) {
        self.stateProvider = engine
        self.enhancementService = enhancementService
    }

    func beginSession(with config: PowerModeConfig) async {
        guard let stateProvider = stateProvider, let enhancementService = enhancementService else {
            print("SessionManager not configured.")
            return
        }

        // Only capture baseline if NO session exists
        if loadSession() == nil {
            let punctuationCleanupMode = PunctuationCleanupMode.current()
            let originalState = ApplicationState(
                isEnhancementEnabled: enhancementService.isEnhancementEnabled,
                useScreenCaptureContext: enhancementService.useScreenCaptureContext,
                selectedPromptId: enhancementService.selectedPromptId?.uuidString,
                selectedAIProvider: enhancementService.getAIService()?.selectedProvider.rawValue,
                selectedAIModel: enhancementService.getAIService()?.currentModel,
                selectedLanguage: UserDefaults.standard.string(forKey: "SelectedLanguage"),
                transcriptionModelName: stateProvider.currentTranscriptionModel?.name,
                isTextFormattingEnabled: UserDefaults.standard.bool(forKey: "IsTextFormattingEnabled"),
                punctuationCleanupMode: punctuationCleanupMode,
                removePunctuation: punctuationCleanupMode == .removeAll,
                lowercaseTranscription: UserDefaults.standard.bool(forKey: "LowercaseTranscription"),
                llmOutputLanguage: UserDefaults.standard.string(forKey: LocalePackRegistry.outputLanguageKey),
                localeNormalizationEnabled: UserDefaults.standard.object(forKey: LocalePackRegistry.normalizationEnabledKey) as? Bool,
                whisperPromptDomain: UserDefaults.standard.string(forKey: WhisperPrompt.domainKey),
                removeFillerWords: UserDefaults.standard.object(forKey: "RemoveFillerWords") as? Bool,
                appendTrailingSpace: UserDefaults.standard.object(forKey: "AppendTrailingSpace") as? Bool
            )

            let newSession = PowerModeSession(
                id: UUID(),
                startTime: Date(),
                originalState: originalState
            )
            saveSession(newSession)

            NotificationCenter.default.addObserver(self, selector: #selector(updateSessionSnapshot), name: .AppSettingsDidChange, object: nil)
        }

        // Always apply the new configuration
        isApplyingPowerModeConfig = true
        await applyConfiguration(config)
        isApplyingPowerModeConfig = false
    }

    var hasActiveSession: Bool {
        return loadSession() != nil
    }

    func endSession() async {
        guard let session = loadSession() else { return }

        isApplyingPowerModeConfig = true
        await restoreState(session.originalState)
        isApplyingPowerModeConfig = false

        NotificationCenter.default.removeObserver(self, name: .AppSettingsDidChange, object: nil)

        clearSession()
    }

    @objc func updateSessionSnapshot() {
        guard !isApplyingPowerModeConfig else { return }

        guard var session = loadSession(),
              let stateProvider = stateProvider,
              let enhancementService = enhancementService else { return }

        let punctuationCleanupMode = PunctuationCleanupMode.current()
        let updatedState = ApplicationState(
            isEnhancementEnabled: enhancementService.isEnhancementEnabled,
            useScreenCaptureContext: enhancementService.useScreenCaptureContext,
            selectedPromptId: enhancementService.selectedPromptId?.uuidString,
            selectedAIProvider: enhancementService.getAIService()?.selectedProvider.rawValue,
            selectedAIModel: enhancementService.getAIService()?.currentModel,
            selectedLanguage: UserDefaults.standard.string(forKey: "SelectedLanguage"),
            transcriptionModelName: stateProvider.currentTranscriptionModel?.name,
            isTextFormattingEnabled: UserDefaults.standard.bool(forKey: "IsTextFormattingEnabled"),
            punctuationCleanupMode: punctuationCleanupMode,
            removePunctuation: punctuationCleanupMode == .removeAll,
            lowercaseTranscription: UserDefaults.standard.bool(forKey: "LowercaseTranscription"),
            llmOutputLanguage: UserDefaults.standard.string(forKey: LocalePackRegistry.outputLanguageKey),
            localeNormalizationEnabled: UserDefaults.standard.object(forKey: LocalePackRegistry.normalizationEnabledKey) as? Bool,
            whisperPromptDomain: UserDefaults.standard.string(forKey: WhisperPrompt.domainKey),
            removeFillerWords: UserDefaults.standard.object(forKey: "RemoveFillerWords") as? Bool,
            appendTrailingSpace: UserDefaults.standard.object(forKey: "AppendTrailingSpace") as? Bool
        )

        session.originalState = updatedState
        saveSession(session)
    }

    private func applyConfiguration(_ config: PowerModeConfig) async {
        guard let enhancementService = enhancementService,
              let stateProvider = stateProvider else { return }

        await MainActor.run {
            // LLM section: gated by `customizeLLM`. When false, every
            // LLM-related field (enhancement toggle, prompt, provider, model)
            // is left at whatever the global state was when the session
            // started, so the Power Mode acts as a transcription-only profile.
            if config.customizeLLM {
                enhancementService.isEnhancementEnabled = config.isAIEnhancementEnabled

                if config.isAIEnhancementEnabled {
                    if let promptId = config.selectedPrompt, let uuid = UUID(uuidString: promptId) {
                        // Guard against orphan references: Power Mode
                        // configs persisted before recent dedup /
                        // template-promotion migrations may point at a
                        // CustomPrompt that no longer exists. Setting the
                        // invalid UUID would make activePrompt resolve to
                        // nil — silently — and the history row's prompt
                        // pill would render blank. Validate the lookup
                        // and fall back to nil (Default) when the prompt
                        // is gone, so getSystemMessage and enhance() both
                        // route through the predefined Default.
                        if enhancementService.allPrompts.contains(where: { $0.id == uuid }) {
                            enhancementService.selectedPromptId = uuid
                        } else {
                            enhancementService.selectedPromptId = nil
                        }
                    }

                    if let aiService = enhancementService.getAIService() {
                        if let providerName = config.selectedAIProvider, let provider = AIProvider(rawValue: providerName) {
                            aiService.selectedProvider = provider
                        }
                        if let model = config.selectedAIModel {
                            aiService.selectModel(model)
                        }
                    }
                }
            }

            enhancementService.useScreenCaptureContext = config.useScreenCapture

            UserDefaults.standard.set(config.isTextFormattingEnabled, forKey: "IsTextFormattingEnabled")
            PunctuationCleanupMode.setCurrent(config.punctuationCleanupMode)
            UserDefaults.standard.set(config.lowercaseTranscription, forKey: "LowercaseTranscription")

            // Optional per-Power-Mode overrides. When the override is nil the
            // profile leaves the system default untouched — this is the
            // "Default" sentinel state surfaced in the editor UI.
            if let value = config.llmOutputLanguageOverride {
                UserDefaults.standard.set(value, forKey: LocalePackRegistry.outputLanguageKey)
            }
            if let value = config.localeNormalizationEnabledOverride {
                UserDefaults.standard.set(value, forKey: LocalePackRegistry.normalizationEnabledKey)
            }
            if let value = config.whisperPromptDomainOverride {
                UserDefaults.standard.set(value, forKey: WhisperPrompt.domainKey)
            }
            if let value = config.removeFillerWordsOverride {
                UserDefaults.standard.set(value, forKey: "RemoveFillerWords")
            }
            if let value = config.appendTrailingSpaceOverride {
                UserDefaults.standard.set(value, forKey: "AppendTrailingSpace")
            }
        }

        // Transcription section: gated by `customizeTranscription`. When
        // false, the model + language stay on whatever the user had set
        // globally, so the Power Mode acts as an LLM-only profile.
        if config.customizeTranscription {
            if let modelName = config.selectedTranscriptionModelName,
               let selectedModel = await stateProvider.allAvailableModels.first(where: { $0.name == modelName }),
               stateProvider.currentTranscriptionModel?.name != modelName {
                await handleModelChange(to: selectedModel)
            }

            if let language = config.selectedLanguage {
                applyCompatibleLanguage(language, preferredModelName: config.selectedTranscriptionModelName)
            }
        }

        await MainActor.run {
            NotificationCenter.default.post(name: .powerModeConfigurationApplied, object: nil)
        }
    }

    private func restoreState(_ state: ApplicationState) async {
        guard let enhancementService = enhancementService,
              let stateProvider = stateProvider else { return }

        await MainActor.run {
            enhancementService.isEnhancementEnabled = state.isEnhancementEnabled
            enhancementService.useScreenCaptureContext = state.useScreenCaptureContext
            enhancementService.selectedPromptId = state.selectedPromptId.flatMap(UUID.init)

            if let aiService = enhancementService.getAIService() {
                if let providerName = state.selectedAIProvider, let provider = AIProvider(rawValue: providerName) {
                    aiService.selectedProvider = provider
                }
                if let model = state.selectedAIModel {
                    aiService.selectModel(model)
                }
            }

            if let isTextFormattingEnabled = state.isTextFormattingEnabled {
                UserDefaults.standard.set(isTextFormattingEnabled, forKey: "IsTextFormattingEnabled")
            }
            if let punctuationCleanupMode = state.punctuationCleanupMode {
                PunctuationCleanupMode.setCurrent(punctuationCleanupMode)
            } else if let removePunctuation = state.removePunctuation {
                PunctuationCleanupMode.setCurrent(removePunctuation ? .removeAll : .keep)
            }
            if let lowercaseTranscription = state.lowercaseTranscription {
                UserDefaults.standard.set(lowercaseTranscription, forKey: "LowercaseTranscription")
            }

            // Restore optional per-Power-Mode override keys back to whatever
            // the user had before the session started. nil here means the
            // key was absent — we mirror that by removing the key so the
            // registered default re-applies.
            applyOptionalString(state.llmOutputLanguage, forKey: LocalePackRegistry.outputLanguageKey)
            applyOptionalBool(state.localeNormalizationEnabled, forKey: LocalePackRegistry.normalizationEnabledKey)
            applyOptionalString(state.whisperPromptDomain, forKey: WhisperPrompt.domainKey)
            applyOptionalBool(state.removeFillerWords, forKey: "RemoveFillerWords")
            applyOptionalBool(state.appendTrailingSpace, forKey: "AppendTrailingSpace")
        }

        if let modelName = state.transcriptionModelName,
           let selectedModel = await stateProvider.allAvailableModels.first(where: { $0.name == modelName }),
           stateProvider.currentTranscriptionModel?.name != modelName {
            await handleModelChange(to: selectedModel)
        }

        if let language = state.selectedLanguage {
            applyCompatibleLanguage(language, preferredModelName: state.transcriptionModelName)
        }
    }

    /// Writes `value` to `forKey` if non-nil, otherwise removes the key so
    /// the registered default from `AppDefaults` becomes the effective value.
    private func applyOptionalBool(_ value: Bool?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func applyOptionalString(_ value: String?, forKey key: String) {
        if let value {
            UserDefaults.standard.set(value, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func applyCompatibleLanguage(_ language: String, preferredModelName: String?) {
        guard let model = model(named: preferredModelName) ?? stateProvider?.currentTranscriptionModel else {
            UserDefaults.standard.set(language, forKey: "SelectedLanguage")
            NotificationCenter.default.post(name: .languageDidChange, object: nil)
            return
        }

        let compatibleLanguage = TranscriptionLanguageSupport.validLanguageOrFallback(language, for: model)
        UserDefaults.standard.set(compatibleLanguage, forKey: "SelectedLanguage")
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }

    private func model(named modelName: String?) -> (any TranscriptionModel)? {
        guard let modelName else { return nil }
        return stateProvider?.allAvailableModels.first { $0.name == modelName }
    }

    private func handleModelChange(to newModel: any TranscriptionModel) async {
        guard let stateProvider = stateProvider else { return }

        await stateProvider.setDefaultTranscriptionModel(newModel)

        switch newModel.provider {
        case .whisper:
            await stateProvider.cleanupModelResources()
            if let whisperModel = await stateProvider.availableModels.first(where: { $0.name == newModel.name }) {
                do {
                    try await stateProvider.loadModel(whisperModel)
                } catch {
                    print("Power Mode: Failed to load local model '\(whisperModel.name)': \(error)")
                }
            }
        case .fluidAudio:
            await stateProvider.cleanupModelResources()
        default:
            await stateProvider.cleanupModelResources()
        }
    }

    private func recoverSession() {
        guard let session = loadSession() else { return }
        print("Recovering abandoned Power Mode session.")
        Task {
            await endSession()
        }
    }

    private func saveSession(_ session: PowerModeSession) {
        do {
            let data = try JSONEncoder().encode(session)
            UserDefaults.standard.set(data, forKey: sessionKey)
        } catch {
            print("Error saving Power Mode session: \(error)")
        }
    }

    private func loadSession() -> PowerModeSession? {
        guard let data = UserDefaults.standard.data(forKey: sessionKey) else { return nil }
        do {
            return try JSONDecoder().decode(PowerModeSession.self, from: data)
        } catch {
            print("Error loading Power Mode session: \(error)")
            return nil
        }
    }

    private func clearSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }
}

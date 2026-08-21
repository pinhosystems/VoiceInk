import Foundation
import SwiftData
import AppKit
import os
import LLMkit

enum EnhancementPrompt {
    case transcriptionEnhancement
    case aiAssistant
}

@MainActor
class AIEnhancementService: ObservableObject {
    private let logger = Logger(subsystem: "agabo.dev.voiceink", category: "AIEnhancementService")

    @Published var isEnhancementEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnhancementEnabled, forKey: "isAIEnhancementEnabled")
            if isEnhancementEnabled && selectedPromptId == nil {
                selectedPromptId = customPrompts.first?.id
            }
            NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
            NotificationCenter.default.post(name: .enhancementToggleChanged, object: nil)
        }
    }

    @Published var useClipboardContext: Bool {
        didSet {
            UserDefaults.standard.set(useClipboardContext, forKey: "useClipboardContext")
        }
    }

    @Published var useScreenCaptureContext: Bool {
        didSet {
            UserDefaults.standard.set(useScreenCaptureContext, forKey: "useScreenCaptureContext")
            NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
        }
    }

    /// Whether the focused app's currently-selected text is attached to the
    /// enhancement prompt. Previously this was always-on (gated only on
    /// Accessibility permission), which produced noisy/inconsistent results in
    /// terminals where "selection" is fragile or wrong.
    @Published var useSelectedTextContext: Bool {
        didSet {
            UserDefaults.standard.set(useSelectedTextContext, forKey: "useSelectedTextContext")
        }
    }

    /// Per-source caps in characters. Default 4000 — comfortable for most chat
    /// completions while protecting against a misreporting terminal returning
    /// tens of KB. The values flow into UserDefaults so the user can tune them.
    static let defaultContextMaxChars: Int = 4000

    @Published var selectedTextContextMaxChars: Int {
        didSet {
            UserDefaults.standard.set(selectedTextContextMaxChars, forKey: "selectedTextContextMaxChars")
        }
    }

    @Published var clipboardContextMaxChars: Int {
        didSet {
            UserDefaults.standard.set(clipboardContextMaxChars, forKey: "clipboardContextMaxChars")
        }
    }

    @Published var screenCaptureContextMaxChars: Int {
        didSet {
            UserDefaults.standard.set(screenCaptureContextMaxChars, forKey: "screenCaptureContextMaxChars")
        }
    }

    @Published var customPrompts: [CustomPrompt] {
        didSet {
            if let encoded = try? JSONEncoder().encode(customPrompts) {
                UserDefaults.standard.set(encoded, forKey: "customPrompts")
            }
        }
    }

    @Published var selectedPromptId: UUID? {
        didSet {
            UserDefaults.standard.set(selectedPromptId?.uuidString, forKey: "selectedPromptId")
            NotificationCenter.default.post(name: .AppSettingsDidChange, object: nil)
            NotificationCenter.default.post(name: .promptSelectionChanged, object: nil)
        }
    }

    @Published var lastSystemMessageSent: String?
    @Published var lastUserMessageSent: String?
    /// Most recent LLM call expressed as an `APICallLog.Step`. Picked up
    /// by the orchestrators (TranscriptionPipeline / retranscribeAudio)
    /// and attached to the Transcription's troubleshooting fixture.
    @Published var lastLLMCallStep: APICallLog.Step?

    var activePrompt: CustomPrompt? {
        allPrompts.first { $0.id == selectedPromptId }
    }

    var allPrompts: [CustomPrompt] {
        return customPrompts
    }

    private let aiService: AIService
    private let screenCaptureService: ScreenCaptureService
    private let customVocabularyService: CustomVocabularyService
    private var baseTimeout: TimeInterval {
        let stored = UserDefaults.standard.integer(forKey: "EnhancementTimeoutSeconds")
        return stored > 0 ? TimeInterval(stored) : 7
    }
    private let rateLimitInterval: TimeInterval = 1.0
    private var lastRequestTime: Date?
    private let modelContext: ModelContext
    
    @Published var lastCapturedClipboard: String?

    init(aiService: AIService = AIService(), modelContext: ModelContext) {
        self.aiService = aiService
        self.modelContext = modelContext
        self.screenCaptureService = ScreenCaptureService()
        self.customVocabularyService = CustomVocabularyService.shared

        self.isEnhancementEnabled = UserDefaults.standard.bool(forKey: "isAIEnhancementEnabled")
        self.useClipboardContext = UserDefaults.standard.bool(forKey: "useClipboardContext")
        self.useScreenCaptureContext = UserDefaults.standard.bool(forKey: "useScreenCaptureContext")
        // Default selected-text context to ON so users on existing installs see
        // identical behavior; the toggle exists so they can turn it off when a
        // terminal or text editor reports flaky selections.
        if UserDefaults.standard.object(forKey: "useSelectedTextContext") == nil {
            UserDefaults.standard.set(true, forKey: "useSelectedTextContext")
        }
        self.useSelectedTextContext = UserDefaults.standard.bool(forKey: "useSelectedTextContext")
        let storedSelectedMax = UserDefaults.standard.integer(forKey: "selectedTextContextMaxChars")
        self.selectedTextContextMaxChars = storedSelectedMax > 0 ? storedSelectedMax : Self.defaultContextMaxChars
        let storedClipboardMax = UserDefaults.standard.integer(forKey: "clipboardContextMaxChars")
        self.clipboardContextMaxChars = storedClipboardMax > 0 ? storedClipboardMax : Self.defaultContextMaxChars
        let storedScreenMax = UserDefaults.standard.integer(forKey: "screenCaptureContextMaxChars")
        self.screenCaptureContextMaxChars = storedScreenMax > 0 ? storedScreenMax : Self.defaultContextMaxChars
        if let savedPromptsData = UserDefaults.standard.data(forKey: "customPrompts"),
           let decodedPrompts = try? JSONDecoder().decode([CustomPrompt].self, from: savedPromptsData) {
            self.customPrompts = decodedPrompts
        } else {
            self.customPrompts = []
        }

        if let savedPromptId = UserDefaults.standard.string(forKey: "selectedPromptId") {
            self.selectedPromptId = UUID(uuidString: savedPromptId)
        }

        // Profile selection is independent of `isEnhancementEnabled`: even
        // when LLM enhancement is off, the active prompt still controls the
        // vocabulary domains used for STT keyterm bias (see
        // `VocabularyResolver`). Auto-pick a default whenever the stored
        // selection is missing or stale.
        if selectedPromptId == nil || !allPrompts.contains(where: { $0.id == selectedPromptId }) {
            self.selectedPromptId = allPrompts.first?.id
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAPIKeyChange),
            name: .aiProviderKeyChanged,
            object: nil
        )

        initializePredefinedPrompts()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleAPIKeyChange() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
            if !self.aiService.isAPIKeyValid {
                self.isEnhancementEnabled = false
            }
        }
    }

    func getAIService() -> AIService? {
        return aiService
    }

    var isConfigured: Bool {
        aiService.isAPIKeyValid
    }

    private func waitForRateLimit() async throws {
        if let lastRequest = lastRequestTime {
            let timeSinceLastRequest = Date().timeIntervalSince(lastRequest)
            if timeSinceLastRequest < rateLimitInterval {
                try await Task.sleep(nanoseconds: UInt64((rateLimitInterval - timeSinceLastRequest) * 1_000_000_000))
            }
        }
        lastRequestTime = Date()
    }

    /// Assembles the context sections (selected text, clipboard, screen,
    /// vocabulary) plus the presence flags. Shared by the classic
    /// enhancement system message and the agentic processor.
    func buildContextAssembly() async -> (contextSection: String, flags: AIPrompts.ContextFlags) {
        let selectedTextContext: String
        if useSelectedTextContext, AXIsProcessTrusted(),
           let selectedText = await SelectedTextService.fetchSelectedText(),
           !selectedText.isEmpty {
            selectedTextContext = wrapContext(
                name: "CURRENTLY_SELECTED_TEXT",
                content: selectedText,
                maxChars: selectedTextContextMaxChars
            )
        } else {
            selectedTextContext = ""
        }

        let clipboardContext: String
        if useClipboardContext,
           let clipboardText = lastCapturedClipboard,
           !clipboardText.isEmpty {
            clipboardContext = wrapContext(
                name: "CLIPBOARD_CONTEXT",
                content: clipboardText,
                maxChars: clipboardContextMaxChars
            )
        } else {
            clipboardContext = ""
        }

        let screenCaptureContext: String
        if useScreenCaptureContext,
           let capturedText = screenCaptureService.lastCapturedText,
           !capturedText.isEmpty {
            screenCaptureContext = wrapContext(
                name: "CURRENT_WINDOW_CONTEXT",
                content: capturedText,
                maxChars: screenCaptureContextMaxChars
            )
        } else {
            screenCaptureContext = ""
        }

        let customVocabulary = customVocabularyService.getCustomVocabulary(from: modelContext)

        let allContextSections = selectedTextContext + clipboardContext + screenCaptureContext

        let customVocabularySection = if !customVocabulary.isEmpty {
            """


            The following are important vocabulary words, proper nouns, and technical terms. When these words or similar-sounding words appear in the <TRANSCRIPT>, ensure they are spelled EXACTLY as shown below:
            <CUSTOM_VOCABULARY>
            \(customVocabulary)
            </CUSTOM_VOCABULARY>
            """
        } else {
            ""
        }

        // Drive the system-instructions wrapper from the *actual* presence of
        // each block, not just the user's toggles. A toggle that is on but
        // produces no content (e.g. an empty clipboard) leaves its tag out
        // of the system message — no point pointing the model at an
        // <empty>...</empty> block.
        let flags = AIPrompts.ContextFlags(
            hasClipboard: !clipboardContext.isEmpty,
            hasScreen: !screenCaptureContext.isEmpty,
            hasSelectedText: !selectedTextContext.isEmpty,
            hasVocabulary: !customVocabulary.isEmpty
        )
        return (allContextSections + customVocabularySection, flags)
    }

    private func getSystemMessage(
        for mode: EnhancementPrompt,
        overridePrompt: CustomPrompt? = nil
    ) async -> String {
        let (finalContextSection, flags) = await buildContextAssembly()

        // Audio language hint — the BCP-47 code the STT engine was
        // configured with. Prepended to every variant of the system
        // message so the LLM never has to guess from a 3-word
        // transcript whether it should respond in English or
        // Portuguese.
        // Resolve via LanguageResolver so the "default" sentinel collapses
        // into Settings → Default language. The LLM step needs a concrete
        // code to build <AUDIO_LANGUAGE> + <LOCALE_RULES>; the sentinel
        // would otherwise leak into the prompt as literal "default".
        let selectedLanguageCode = LanguageResolver.effectiveSTTCode()
        // The STT pack stays tied to the STT language for Whisper seeds,
        // vocabulary biasing, and filler removal. The LLM-side pack — which
        // drives the <LOCALE_RULES> block — follows the override below, so
        // a user transcribing pt-BR audio can ask for the LLM response in
        // English without touching the STT picker.
        let outputLanguageCode = LocalePackRegistry.outputLanguageCode(sttCode: selectedLanguageCode)
        let languageBlock = AIPrompts.audioLanguageBlock(
            sttCode: selectedLanguageCode,
            outputCode: outputLanguageCode
        )
        let activePack = LocalePackRegistry.pack(for: outputLanguageCode)

        // Per-locale tech-term salvage table. Non-English speakers
        // routinely mix English dev jargon into their dictation
        // ("comêti", "puxe", "taipiscripti") — the STT writes the
        // phonetic form and the LLM has no signal to recover the
        // canonical English term unless we point at the patterns
        // explicitly. Inject for ANY active prompt as long as the
        // configured language has a salvage table. The category gate
        // used to be coding/dev_ai-only but the same problem hits
        // chat messages, emails, and freeform writing — anywhere the
        // user might say "commit" or "deploy" mid-sentence — so we
        // pay the ~200-token cost across the board on non-EN locales.
        // EN / auto locales still return nil and skip the block.
        let salvageBlock = TechTermSalvage.block(forLanguageCode: selectedLanguageCode) ?? ""

        let promptBody: String
        let resolvedPrompt = overridePrompt ?? activePrompt
        if let resolvedPrompt {
            if resolvedPrompt.id == PredefinedPrompts.assistantPromptId {
                promptBody = AIPrompts.assistantMode(flags: flags, pack: activePack)
            } else {
                promptBody = resolvedPrompt.finalPromptText(flags: flags, pack: activePack)
            }
        } else {
            // Fallback chain, in order of preference:
            //   1. The canonical "Default" predefined prompt by stable UUID.
            //   2. Any prompt that happens to exist in `allPrompts`.
            //   3. The hard-coded predefined prompts (always non-empty at the source).
            // We avoid force-unwrap because allPrompts can be empty in degenerate
            // states (corrupted persistence, migration failure, first launch race).
            let fallback = allPrompts.first(where: { $0.id == PredefinedPrompts.defaultPromptId })
                ?? allPrompts.first
                ?? PredefinedPrompts.createDefaultPrompts().first
            guard let defaultPrompt = fallback else {
                return languageBlock + salvageBlock + finalContextSection
            }
            promptBody = defaultPrompt.finalPromptText(flags: flags, pack: activePack)
        }
        return languageBlock + salvageBlock + promptBody + finalContextSection
    }

    /// Building blocks for the agentic processor's system prompt: the same
    /// language / locale / salvage / context assembly as the classic system
    /// message, but with the active prompt's raw body separated out and the
    /// anti-command wrapper omitted — the agent defines its own contract for
    /// when the transcript is data vs. an instruction.
    struct AgenticComponents {
        let languageBlock: String
        let localeRules: String
        let salvageBlock: String
        let activePromptTitle: String
        let activePromptRules: String
        let contextSection: String
    }

    func agenticSystemComponents() async -> AgenticComponents {
        let (contextSection, flags) = await buildContextAssembly()
        let sttCode = LanguageResolver.effectiveSTTCode()
        let outputCode = LocalePackRegistry.outputLanguageCode(sttCode: sttCode)
        let pack = LocalePackRegistry.pack(for: outputCode)

        let rules: String
        if let active = activePrompt {
            rules = active.id == PredefinedPrompts.assistantPromptId
                ? AIPrompts.assistantMode(flags: flags, pack: pack)
                : active.promptText
        } else {
            rules = PredefinedPrompts.createDefaultPrompts().first?.promptText ?? ""
        }

        return AgenticComponents(
            languageBlock: AIPrompts.audioLanguageBlock(sttCode: sttCode, outputCode: outputCode),
            localeRules: AIPrompts.localeRulesBlock(pack: pack),
            salvageBlock: TechTermSalvage.block(forLanguageCode: sttCode) ?? "",
            activePromptTitle: activePrompt?.title ?? "Default",
            activePromptRules: rules,
            contextSection: contextSection
        )
    }

    private func makeRequest(
        text: String,
        mode: EnhancementPrompt,
        overridePrompt: CustomPrompt? = nil
    ) async throws -> String {
        guard isConfigured else {
            throw EnhancementError.notConfigured
        }

        guard !text.isEmpty else {
            return ""
        }

        let formattedText = "\n<TRANSCRIPT>\n\(text)\n</TRANSCRIPT>"
        let systemMessage = await getSystemMessage(for: mode, overridePrompt: overridePrompt)

        await MainActor.run {
            self.lastSystemMessageSent = systemMessage
            self.lastUserMessageSent = formattedText
            // Seed a fresh log step so a downstream throw still ends up
            // attached to the transcription with the error captured below.
            self.lastLLMCallStep = APICallLog.Step(
                kind: .llm,
                provider: aiService.selectedProvider.rawValue,
                providerVariant: nil,
                endpointHost: nil,
                model: aiService.currentModel,
                languageCode: nil,
                requestSummary: nil,
                requestSystemMessage: systemMessage,
                requestUserMessage: formattedText,
                responseSummary: nil,
                durationMs: nil,
                errorMessage: nil
            )
        }

        let provider = aiService.selectedProvider
        let model = aiService.currentModel
        let endpointHost = APICallLog.host(from: provider.baseURL)
        let variant: String = {
            switch provider {
            case .ollama: return "Local server"
            case .localCLI: return "Local CLI"
            case .custom: return "Custom (OpenAI-compatible)"
            default: return "Cloud"
            }
        }()
        let startedAt = Date()

        func record(response: String?, error: String?) async {
            let durationMs = Int(Date().timeIntervalSince(startedAt) * 1000)
            await MainActor.run {
                self.lastLLMCallStep = APICallLog.Step(
                    kind: .llm,
                    provider: provider.rawValue,
                    providerVariant: variant,
                    endpointHost: endpointHost,
                    model: model,
                    languageCode: nil,
                    requestSummary: nil,
                    requestSystemMessage: systemMessage,
                    requestUserMessage: formattedText,
                    responseSummary: response,
                    durationMs: durationMs,
                    errorMessage: error
                )
            }
        }

        if provider == .ollama {
            do {
                let result = try await aiService.enhanceWithOllama(
                    text: formattedText,
                    systemPrompt: systemMessage,
                    timeout: baseTimeout
                )
                let filtered = AIEnhancementOutputFilter.filter(result)
                await record(response: filtered, error: nil)
                return filtered
            } catch {
                let mapped: EnhancementError
                if let localError = error as? LocalAIError {
                    switch localError {
                    case .timeout: mapped = .timeout
                    default: mapped = .customError(localError.errorDescription ?? "An unknown Ollama error occurred.")
                    }
                } else {
                    mapped = .customError(error.localizedDescription)
                }
                await record(response: nil, error: mapped.errorDescription)
                throw mapped
            }
        }

        if provider == .localCLI {
            do {
                let result = try await aiService.enhanceWithLocalCLI(systemPrompt: systemMessage, userPrompt: formattedText)
                let filtered = AIEnhancementOutputFilter.filter(result)
                await record(response: filtered, error: nil)
                return filtered
            } catch {
                let mapped: EnhancementError
                if let localError = error as? LocalCLIError {
                    mapped = .customError(localError.errorDescription ?? "An unknown Local CLI error occurred.")
                } else {
                    mapped = .customError(error.localizedDescription)
                }
                await record(response: nil, error: mapped.errorDescription)
                throw mapped
            }
        }

        try await waitForRateLimit()

        do {
            let result: String
            switch provider {
            case .anthropic:
                result = try await AnthropicLLMClient.chatCompletion(
                    apiKey: aiService.apiKey,
                    model: model,
                    messages: [.user(formattedText)],
                    systemPrompt: systemMessage,
                    timeout: baseTimeout
                )
            default:
                guard let baseURL = URL(string: provider.baseURL) else {
                    let mapped = EnhancementError.customError("\(provider.rawValue) has an invalid API endpoint URL. Please update it in AI settings.")
                    await record(response: nil, error: mapped.errorDescription)
                    throw mapped
                }
                let temperature = model.lowercased().hasPrefix("gpt-5") ? 1.0 : 0.3
                let reasoningEffort = ReasoningConfig.getReasoningParameter(for: provider, modelName: model)
                let extraBody = ReasoningConfig.getExtraBodyParameters(for: provider, modelName: model)
                result = try await OpenAILLMClient.chatCompletion(
                    baseURL: baseURL,
                    apiKey: aiService.apiKey,
                    model: model,
                    messages: [.user(formattedText)],
                    systemPrompt: systemMessage,
                    temperature: temperature,
                    reasoningEffort: reasoningEffort,
                    extraBody: extraBody,
                    timeout: baseTimeout
                )
            }
            let filtered = AIEnhancementOutputFilter.filter(result.trimmingCharacters(in: .whitespacesAndNewlines))
            await record(response: filtered, error: nil)
            return filtered
        } catch let error as LLMKitError {
            let mapped = mapLLMKitError(error)
            await record(response: nil, error: mapped.errorDescription)
            throw mapped
        } catch let error as EnhancementError {
            await record(response: nil, error: error.errorDescription)
            throw error
        } catch {
            let mapped = EnhancementError.customError(error.localizedDescription)
            await record(response: nil, error: mapped.errorDescription)
            throw mapped
        }
    }

    private func mapLLMKitError(_ error: LLMKitError) -> EnhancementError {
        switch error {
        case .missingAPIKey:
            return .notConfigured
        case .httpError(let statusCode, let message):
            if statusCode == 429 { return .rateLimitExceeded }
            if (500...599).contains(statusCode) { return .serverError }
            return .customError("HTTP \(statusCode): \(message)")
        case .noResultReturned:
            return .enhancementFailed
        case .networkError:
            return .networkError
        case .timeout:
            return .timeout
        case .invalidURL, .decodingError, .encodingError:
            return .customError(error.localizedDescription ?? "An unknown error occurred.")
        }
    }

    private var retryOnTimeout: Bool {
        UserDefaults.standard.bool(forKey: "EnhancementRetryOnTimeout")
    }

    private func makeRequestWithRetry(text: String, mode: EnhancementPrompt, overridePrompt: CustomPrompt? = nil, maxRetries: Int = 3, initialDelay: TimeInterval = 1.0) async throws -> String {
        var retries = 0
        var currentDelay = initialDelay

        while retries < maxRetries {
            do {
                return try await makeRequest(text: text, mode: mode, overridePrompt: overridePrompt)
            } catch let error as EnhancementError {
                switch error {
                case .networkError, .serverError, .rateLimitExceeded:
                    retries += 1
                    if retries < maxRetries {
                        logger.warning("Request failed, retrying in \(currentDelay, privacy: .public)s... (Attempt \(retries, privacy: .public)/\(maxRetries, privacy: .public))")
                        try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                        currentDelay *= 2
                    } else {
                        logger.error("Request failed after \(maxRetries, privacy: .public) retries.")
                        throw error
                    }
                case .timeout:
                    if retryOnTimeout {
                        retries += 1
                        if retries < maxRetries {
                            logger.warning("Request timed out, retrying immediately... (Attempt \(retries, privacy: .public)/\(maxRetries, privacy: .public))")
                        } else {
                            logger.error("Request timed out after \(maxRetries, privacy: .public) retries.")
                            throw error
                        }
                    } else {
                        logger.error("Request timed out, failing immediately (retry disabled).")
                        throw error
                    }
                default:
                    throw error
                }
            } catch {
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && [NSURLErrorNotConnectedToInternet, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost].contains(nsError.code) {
                    retries += 1
                    if retries < maxRetries {
                        logger.warning("Request failed with network error, retrying in \(currentDelay, privacy: .public)s... (Attempt \(retries, privacy: .public)/\(maxRetries, privacy: .public))")
                        try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                        currentDelay *= 2
                    } else {
                        logger.error("Request failed after \(maxRetries, privacy: .public) retries with network error.")
                        throw EnhancementError.networkError
                    }
                } else {
                    throw error
                }
            }
        }

        throw EnhancementError.enhancementFailed
    }

    func enhance(_ text: String, overridePrompt: CustomPrompt? = nil) async throws -> (String, TimeInterval, String?) {
        let startTime = Date()
        let enhancementPrompt: EnhancementPrompt = .transcriptionEnhancement
        // Report the prompt that *actually* drove the LLM call so the
        // history row's prompt pill is faithful even when activePrompt
        // is nil — Power Mode configs whose stored selectedPrompt
        // UUID points at a CustomPrompt removed by the dedup
        // migrations resolve to nil here, but getSystemMessage falls
        // back to Default. The history should show "Default", not
        // empty.
        let effectivePrompt: CustomPrompt? = overridePrompt
            ?? activePrompt
            ?? allPrompts.first(where: { $0.id == PredefinedPrompts.defaultPromptId })
            ?? allPrompts.first
        let promptName = effectivePrompt?.title

        do {
            let result = try await makeRequestWithRetry(text: text, mode: enhancementPrompt, overridePrompt: overridePrompt)
            let endTime = Date()
            let duration = endTime.timeIntervalSince(startTime)
            return (result, duration, promptName)
        } catch {
            throw error
        }
    }

    /// Wraps a context payload in its XML tag, truncating the content to
    /// `maxChars` if needed. Truncation happens inside the tag so the LLM still
    /// sees a well-formed block; an explicit "[truncated]" suffix flags the cut
    /// for the model. Caps below 1 are treated as "unlimited" so a user typo
    /// (e.g. clearing the field) does not silently drop the whole context.
    private func wrapContext(name: String, content: String, maxChars: Int) -> String {
        let payload: String
        if maxChars > 0 && content.count > maxChars {
            payload = String(content.prefix(maxChars)) + "…[truncated]"
            logger.notice("Context \(name, privacy: .public) truncated from \(content.count, privacy: .public) to \(maxChars, privacy: .public) chars")
        } else {
            payload = content
        }
        return "\n\n<\(name)>\n\(payload)\n</\(name)>"
    }

    func captureScreenContext() async {
        guard CGPreflightScreenCaptureAccess() else {
            return
        }

        if let capturedText = await screenCaptureService.captureAndExtractText() {
            await MainActor.run {
                self.objectWillChange.send()
            }
        }
    }

    func captureClipboardContext() {
        lastCapturedClipboard = NSPasteboard.general.string(forType: .string)
    }
    
    func clearCapturedContexts() {
        lastCapturedClipboard = nil
        screenCaptureService.lastCapturedText = nil
    }

    func addPrompt(title: String, promptText: String, icon: PromptIcon = "doc.text.fill", description: String? = nil, triggerWords: [String] = [], useSystemInstructions: Bool = true, category: PromptCategory = .writing) {
        let newPrompt = CustomPrompt(title: title, promptText: promptText, icon: icon, description: description, isPredefined: false, triggerWords: triggerWords, useSystemInstructions: useSystemInstructions, category: category)
        customPrompts.append(newPrompt)
        if customPrompts.count == 1 {
            selectedPromptId = newPrompt.id
        }
    }

    func updatePrompt(_ prompt: CustomPrompt) {
        if let index = customPrompts.firstIndex(where: { $0.id == prompt.id }) {
            customPrompts[index] = prompt
        }
    }

    func deletePrompt(_ prompt: CustomPrompt) {
        customPrompts.removeAll { $0.id == prompt.id }
        if selectedPromptId == prompt.id {
            selectedPromptId = allPrompts.first?.id
        }
    }

    func setActivePrompt(_ prompt: CustomPrompt) {
        selectedPromptId = prompt.id
    }

    private func initializePredefinedPrompts() {
        let predefinedTemplates = PredefinedPrompts.createDefaultPrompts()
        let validPredefinedIds = Set(predefinedTemplates.map { $0.id })
        let predefinedTitles = Set(predefinedTemplates.map { $0.title })

        // Purge orphan predefined prompts: entries persisted with
        // `isPredefined: true` whose UUID is no longer in the source list.
        // Without this, a prompt that used to be predefined and was later
        // removed from `PredefinedPrompts` stays stuck — the delete UI
        // guards on `!isPredefined`, so the user can never remove it.
        customPrompts.removeAll { $0.isPredefined && !validPredefinedIds.contains($0.id) }

        // Migrate legacy clones: Task Prompt (and any other prompt) was
        // previously a clonable template — every application of the
        // "AI Coding Agent" Power Mode preset spawned a fresh
        // non-predefined "Task Prompt" entry, so users with multiple
        // applies ended up with two or three duplicates. Now that the
        // prompt is a predefined entry with a stable UUID, drop the
        // non-predefined siblings whose title matches a current
        // predefined title. The single predefined instance below the
        // loop replaces them in the picker.
        customPrompts.removeAll { !$0.isPredefined && predefinedTitles.contains($0.title) }

        // De-duplicate user-cloned templates: every "Add new prompt
        // from template" click spawned a fresh CustomPrompt with a new
        // UUID but identical title + promptText. Users who explored
        // the template library now see four "Code Comment" and three
        // "Chat" entries in the picker. Collapse exact (title,
        // promptText) duplicates among non-predefined prompts, keeping
        // the earliest occurrence so any persisted selectedPromptId
        // referencing it still resolves. Prompts the user actually
        // edited (different promptText) are untouched.
        var seenSignatures: Set<String> = []
        customPrompts = customPrompts.filter { prompt in
            guard !prompt.isPredefined else { return true }
            let signature = "\(prompt.title)\u{1F}\(prompt.promptText)"
            if seenSignatures.contains(signature) {
                return false
            }
            seenSignatures.insert(signature)
            return true
        }

        // Re-tag legacy template clones with the right PromptCategory.
        // Builds shipped before the category field existed decoded old
        // CustomPrompts with category=.writing regardless of source, so
        // a user's cloned "Commit Message" or "Code Comment" never
        // qualified for the runtime tech-term salvage injection in
        // getSystemMessage. Look each non-predefined prompt up by title
        // in PromptTemplates and, if the persisted category doesn't
        // match the source template's, rewrite it. The prompt's UUID,
        // promptText edits, trigger words, and other user-owned fields
        // are preserved.
        let templateByTitle = Dictionary(
            uniqueKeysWithValues: PromptTemplates.all.map { ($0.title, $0) }
        )
        customPrompts = customPrompts.map { prompt -> CustomPrompt in
            guard !prompt.isPredefined,
                  let template = templateByTitle[prompt.title],
                  prompt.category != template.category else { return prompt }
            return CustomPrompt(
                id: prompt.id,
                title: prompt.title,
                promptText: prompt.promptText,
                isActive: prompt.isActive,
                icon: prompt.icon,
                description: prompt.description,
                isPredefined: prompt.isPredefined,
                triggerWords: prompt.triggerWords,
                useSystemInstructions: prompt.useSystemInstructions,
                vocabularyDomains: prompt.vocabularyDomains,
                category: template.category
            )
        }

        // One-time seeding of default trigger words: the upsert below
        // deliberately preserves user-edited triggerWords, so entries
        // persisted before defaults existed would stay empty forever.
        // Runs once; a user who later clears a trigger list keeps it clear.
        let triggerSeedKey = "PredefinedTriggerWordsSeeded.v1"
        let shouldSeedTriggers = !UserDefaults.standard.bool(forKey: triggerSeedKey)

        for template in predefinedTemplates {
            if let existingIndex = customPrompts.firstIndex(where: { $0.id == template.id }) {
                var updatedPrompt = customPrompts[existingIndex]
                let preservedTriggers = updatedPrompt.triggerWords.isEmpty && shouldSeedTriggers
                    ? template.triggerWords
                    : updatedPrompt.triggerWords
                updatedPrompt = CustomPrompt(
                    id: updatedPrompt.id,
                    title: template.title,
                    promptText: template.promptText,
                    isActive: updatedPrompt.isActive,
                    icon: template.icon,
                    description: template.description,
                    isPredefined: true,
                    triggerWords: preservedTriggers,
                    useSystemInstructions: template.useSystemInstructions,
                    vocabularyDomains: template.vocabularyDomains,
                    category: template.category
                )
                customPrompts[existingIndex] = updatedPrompt
            } else {
                customPrompts.append(template)
            }
        }
        if shouldSeedTriggers {
            UserDefaults.standard.set(true, forKey: triggerSeedKey)
        }
    }
}

enum EnhancementError: Error {
    case notConfigured
    case invalidResponse
    case enhancementFailed
    case networkError
    case serverError
    case rateLimitExceeded
    case timeout
    case customError(String)
}

extension EnhancementError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "AI provider not configured. Please check your API key."
        case .invalidResponse:
            return "Invalid response from AI provider."
        case .enhancementFailed:
            return "AI enhancement failed to process the text."
        case .networkError:
            return "Network connection failed. Check your internet."
        case .serverError:
            return "The AI provider's server encountered an error. Please try again later."
        case .rateLimitExceeded:
            return "Rate limit exceeded. Please try again later."
        case .timeout:
            return "Enhancement request timed out. Check your connection or increase the timeout duration."
        case .customError(let message):
            return message
        }
    }
}

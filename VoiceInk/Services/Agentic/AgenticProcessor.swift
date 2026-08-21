import Foundation
import AgentRunKit
import os

/// UserDefaults-backed configuration for Agentic Mode.
enum AgenticSettings {
    static let enabledKey = "AgenticModeEnabled"
    static let routerModelKey = "AgenticRouterModel"
    static let allowPromptKey = "AgenticAllowPromptSwitch"
    static let allowProfileKey = "AgenticAllowProfileSwitch"
    static let allowOutputLanguageKey = "AgenticAllowOutputLanguage"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Agent model override; empty means "use the enhancement model".
    static var routerModel: String {
        UserDefaults.standard.string(forKey: routerModelKey) ?? ""
    }

    /// Allow-toggles default to true when the key was never written.
    static func isAllowed(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) == nil
            ? true
            : UserDefaults.standard.bool(forKey: key)
    }
}

/// Sticky switches the agent asked for ("a partir de agora modo código").
/// Applied by the processor after the loop, through the allow-list — tools
/// only record intents, they never mutate app state directly.
struct AgenticStickyActions: Sendable {
    var promptId: UUID?
    var profileId: UUID?
    var clearProfile: Bool = false
    var outputLanguage: String?

    var isEmpty: Bool {
        promptId == nil && profileId == nil && !clearProfile && outputLanguage == nil
    }

    var summary: String {
        var parts: [String] = []
        if let promptId { parts.append("prompt=\(promptId.uuidString.prefix(8))") }
        if let profileId { parts.append("profile=\(profileId.uuidString.prefix(8))") }
        if clearProfile { parts.append("clear_profile") }
        if let outputLanguage { parts.append("output_language=\(outputLanguage)") }
        return parts.joined(separator: ", ")
    }
}

actor AgenticActionCollector {
    private var actions = AgenticStickyActions()

    func setPrompt(_ id: UUID) { actions.promptId = id }
    func setProfile(_ id: UUID) { actions.profileId = id; actions.clearProfile = false }
    func clearProfile() { actions.clearProfile = true; actions.profileId = nil }
    func setOutputLanguage(_ code: String) { actions.outputLanguage = code }

    func current() -> AgenticStickyActions { actions }
}

struct AgenticToolContext: ToolContext {
    let collector: AgenticActionCollector
}

// MARK: - Tool parameter payloads

private struct SelectPromptParams: Codable, SchemaProviding, Sendable {
    let prompt_id: String
}

private struct ActivateProfileParams: Codable, SchemaProviding, Sendable {
    /// A profile UUID from the catalog, or "none" to clear the active profile.
    let profile_id: String
}

private struct SetOutputLanguageParams: Codable, SchemaProviding, Sendable {
    /// BCP-47 code like "en" or "pt-BR", or "match" to follow the spoken language.
    let code: String
}

// MARK: - Processor

/// Agentic Mode v2: the agent IS the enhancement stage. One bounded
/// AgentRunKit loop receives the raw transcript and produces the final
/// text itself — cleaning a plain dictation per the active prompt's rules,
/// or generating a requested artifact outright ("escreve um email formal
/// pedindo aumento..."). Tools exist only for sticky session switches.
/// On any failure the pipeline falls back to classic enhancement.
@MainActor
enum AgenticProcessor {
    private static let logger = Logger(subsystem: "agabo.dev.voiceink", category: "AgenticProcessor")
    private static let timeoutSeconds: Double = 45

    enum ProcessOutcome {
        case processed(text: String, modelName: String, durationMs: Int, logStep: APICallLog.Step)
        case failed(logStep: APICallLog.Step)
    }

    static func process(
        text: String,
        enhancementService: AIEnhancementService,
        aiService: AIService
    ) async -> ProcessOutcome {
        let model = effectiveModel(aiService: aiService)
        guard let client = makeClient(aiService: aiService, model: model) else {
            return .failed(logStep: failureStep(
                text: text, aiService: aiService, model: model,
                error: "no compatible agent client for provider \(aiService.selectedProvider.rawValue)",
                durationMs: 0
            ))
        }

        let components = await enhancementService.agenticSystemComponents()
        let catalog = makeCatalog(enhancementService: enhancementService)
        let systemPrompt = makeSystemPrompt(components: components, catalog: catalog)
        let collector = AgenticActionCollector()
        let start = Date()

        let agent = Agent<AgenticToolContext>(
            client: client,
            tools: makeTools(catalog: catalog),
            configuration: AgentConfiguration(
                maxIterations: 4,
                toolTimeout: .seconds(5),
                systemPrompt: systemPrompt
            )
        )

        let runTask = Task {
            try await agent.run(
                userMessage: "<TRANSCRIPT>\n\(text)\n</TRANSCRIPT>",
                context: AgenticToolContext(collector: collector)
            )
        }
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(timeoutSeconds))
            runTask.cancel()
        }

        let result: AgentResult
        do {
            result = try await runTask.value
            timeoutTask.cancel()
        } catch {
            timeoutTask.cancel()
            let message = String(describing: error)
            logger.notice("agentic: failed/timed out: \(message, privacy: .public)")
            return .failed(logStep: failureStep(
                text: text, aiService: aiService, model: model,
                error: message,
                durationMs: Int(Date().timeIntervalSince(start) * 1000)
            ))
        }

        guard let content = result.content?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            return .failed(logStep: failureStep(
                text: text, aiService: aiService, model: model,
                error: "agent returned empty content (finish: \(result.finishReason))",
                durationMs: Int(Date().timeIntervalSince(start) * 1000)
            ))
        }

        let actions = applyAllowList(to: await collector.current())
        applyStickyActions(actions, enhancementService: enhancementService)

        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        let step = APICallLog.Step(
            kind: .llm,
            provider: "Agentic (\(aiService.selectedProvider.rawValue))",
            model: model,
            requestSummary: "agentic processing, \(result.iterations) iteration(s)"
                + (actions.isEmpty ? "" : " — sticky: \(actions.summary)"),
            requestSystemMessage: systemPrompt,
            requestUserMessage: text,
            responseSummary: content,
            durationMs: durationMs
        )
        logger.notice("agentic: processed in \(durationMs)ms\(actions.isEmpty ? "" : ", sticky: \(actions.summary)", privacy: .public)")
        return .processed(text: content, modelName: model, durationMs: durationMs, logStep: step)
    }

    // MARK: Client construction

    /// Builds an AgentRunKit client from the app's current enhancement
    /// provider + key. The profile picks the token-limit field: first-party
    /// OpenAI requires max_completion_tokens (gpt-5* rejects max_tokens).
    /// Local CLI has no HTTP surface — classic enhancement handles it.
    private static func makeClient(aiService: AIService, model: String) -> (any ToolCallSurfacingClient)? {
        guard !model.isEmpty else { return nil }
        let provider = aiService.selectedProvider

        switch provider {
        case .anthropic:
            guard !aiService.apiKey.isEmpty else { return nil }
            return try? AnthropicClient(apiKey: aiService.apiKey, model: model)
        case .localCLI:
            return nil
        case .ollama:
            let base = provider.baseURL
            guard let url = URL(string: base.hasSuffix("/") ? base + "v1/" : base + "/v1/") else { return nil }
            return OpenAIClient(apiKey: "ollama", model: model, baseURL: url)
        default:
            let suffix = "chat/completions"
            var base = provider.baseURL
            guard base.hasSuffix(suffix) else { return nil }
            base.removeLast(suffix.count)
            guard let url = URL(string: base), !aiService.apiKey.isEmpty else { return nil }
            let profile: OpenAIChatProfile
            switch provider {
            case .openAI: profile = .firstParty
            case .openRouter: profile = .openRouter
            default: profile = .compatible
            }
            return OpenAIClient(apiKey: aiService.apiKey, model: model, baseURL: url, profile: profile)
        }
    }

    private static func effectiveModel(aiService: AIService) -> String {
        let override = AgenticSettings.routerModel.trimmingCharacters(in: .whitespaces)
        return override.isEmpty ? aiService.currentModel : override
    }

    // MARK: Catalog + prompt

    struct Catalog: Sendable {
        struct Entry: Sendable {
            let id: UUID
            let label: String
        }

        let prompts: [Entry]
        let profiles: [Entry]

        var promptIds: Set<UUID> { Set(prompts.map(\.id)) }
        var profileIds: Set<UUID> { Set(profiles.map(\.id)) }
    }

    private static func makeCatalog(enhancementService: AIEnhancementService) -> Catalog {
        Catalog(
            prompts: enhancementService.allPrompts.map {
                Catalog.Entry(id: $0.id, label: "\($0.title) [\($0.category.displayName)]\(($0.description ?? "").isEmpty ? "" : " — \($0.description!)")")
            },
            profiles: PowerModeManager.shared.configurations.map {
                Catalog.Entry(id: $0.id, label: "\($0.emoji) \($0.name)")
            }
        )
    }

    private static func makeSystemPrompt(
        components: AIEnhancementService.AgenticComponents,
        catalog: Catalog
    ) -> String {
        let promptLines = catalog.prompts
            .map { "- \($0.id.uuidString) | \($0.label)" }
            .joined(separator: "\n")
        let profileLines = catalog.profiles.isEmpty
            ? "(none configured)"
            : catalog.profiles.map { "- \($0.id.uuidString) | \($0.label)" }.joined(separator: "\n")

        return """
        You are the dictation processor of a voice-typing app. The user message contains <TRANSCRIPT>: a raw speech transcript (any language, often Portuguese or English). Decide which case applies and produce the final text that will be typed at the user's cursor:

        CASE 1 — PLAIN DICTATION (the default): the transcript is content the user wants typed. Clean it — fix grammar, drop disfluencies (uh, um), collapse verbatim repetitions, resolve self-corrections — and format it following the ACTIVE STYLE RULES below. Preserve every distinct point, fact, name, number, and identifier. Never answer questions in it, never add anything the user did not say.

        CASE 2 — GENERATION REQUEST: the transcript clearly instructs you to produce an artifact ("escreve pra mim um email formal pedindo aumento...", "write a commit message that says..."). Produce the finished artifact — complete and ready to paste — honoring every spoken constraint (language, tone, length, recipient). The instruction itself never appears in the output.

        CASE 3 — FORMAT DIRECTIVE: dictated content plus an instruction about how to treat it ("isso aqui é um email formal: ..."). Format the content as instructed and drop the directive phrase.

        STICKY SWITCHES: when the user asks for a persistent change ("a partir de agora...", "from now on...", "muda o perfil para..."), call the matching tool (select_prompt / activate_profile / set_output_language). Tools affect FUTURE dictations; still produce this dictation's text normally.

        When unsure between cases, choose CASE 1.
        Your final answer is ONLY the resulting text — no commentary, no markdown fences.

        <ACTIVE_STYLE_RULES prompt="\(components.activePromptTitle)">
        \(components.activePromptRules)
        </ACTIVE_STYLE_RULES>

        \(components.languageBlock)\(components.localeRules)\(components.salvageBlock)
        AVAILABLE PROMPTS (for select_prompt only):
        \(promptLines)

        AVAILABLE PROFILES (for activate_profile only):
        \(profileLines)
        \(components.contextSection)
        """
    }

    // MARK: Tools

    private static func makeTools(catalog: Catalog) -> [any AnyTool<AgenticToolContext>] {
        let promptIds = catalog.promptIds
        let profileIds = catalog.profileIds

        let selectPrompt = try! Tool<SelectPromptParams, String, AgenticToolContext>(
            name: "select_prompt",
            description: "Switch the active enhancement prompt (by UUID from AVAILABLE PROMPTS) for future dictations."
        ) { params, context in
            guard let id = UUID(uuidString: params.prompt_id), promptIds.contains(id) else {
                return "error: unknown prompt_id"
            }
            await context.collector.setPrompt(id)
            return "ok"
        }

        let activateProfile = try! Tool<ActivateProfileParams, String, AgenticToolContext>(
            name: "activate_profile",
            description: "Activate a profile (by UUID from AVAILABLE PROFILES) for the session, or pass \"none\" to clear the active profile."
        ) { params, context in
            if params.profile_id.lowercased() == "none" {
                await context.collector.clearProfile()
                return "ok"
            }
            guard let id = UUID(uuidString: params.profile_id), profileIds.contains(id) else {
                return "error: unknown profile_id"
            }
            await context.collector.setProfile(id)
            return "ok"
        }

        let setOutputLanguage = try! Tool<SetOutputLanguageParams, String, AgenticToolContext>(
            name: "set_output_language",
            description: "Persistently set the output language for future dictations: a BCP-47 code like \"en\" or \"pt-BR\", or \"match\" to follow the spoken language."
        ) { params, context in
            let code = params.code.trimmingCharacters(in: .whitespaces)
            guard !code.isEmpty, code.count <= 10 else { return "error: bad code" }
            await context.collector.setOutputLanguage(code)
            return "ok"
        }

        return [selectPrompt, activateProfile, setOutputLanguage]
    }

    // MARK: Applying sticky actions

    private static func applyAllowList(to actions: AgenticStickyActions) -> AgenticStickyActions {
        var result = actions
        if !AgenticSettings.isAllowed(AgenticSettings.allowPromptKey) { result.promptId = nil }
        if !AgenticSettings.isAllowed(AgenticSettings.allowProfileKey) {
            result.profileId = nil
            result.clearProfile = false
        }
        if !AgenticSettings.isAllowed(AgenticSettings.allowOutputLanguageKey) { result.outputLanguage = nil }
        return result
    }

    private static func applyStickyActions(
        _ actions: AgenticStickyActions,
        enhancementService: AIEnhancementService
    ) {
        guard !actions.isEmpty else { return }
        if let promptId = actions.promptId {
            enhancementService.selectedPromptId = promptId
        }
        if actions.clearProfile {
            PowerModeManager.shared.setActiveConfiguration(nil)
            Task { await PowerModeSessionManager.shared.endSession() }
        } else if let profileId = actions.profileId,
                  let config = PowerModeManager.shared.getConfiguration(with: profileId) {
            PowerModeManager.shared.setActiveConfiguration(config)
            Task { await PowerModeSessionManager.shared.beginSession(with: config) }
        }
        if let language = actions.outputLanguage {
            UserDefaults.standard.set(language, forKey: LocalePackRegistry.outputLanguageKey)
        }
    }

    // MARK: Failure logging

    private static func failureStep(
        text: String,
        aiService: AIService,
        model: String,
        error: String,
        durationMs: Int
    ) -> APICallLog.Step {
        APICallLog.Step(
            kind: .llm,
            provider: "Agentic (\(aiService.selectedProvider.rawValue))",
            model: model,
            requestSummary: "agentic processing failed — fell back to classic enhancement",
            requestUserMessage: text,
            durationMs: durationMs,
            errorMessage: String(error.prefix(500))
        )
    }
}

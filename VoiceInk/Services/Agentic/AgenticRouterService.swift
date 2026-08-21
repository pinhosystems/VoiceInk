import Foundation
import AgentRunKit
import os

/// UserDefaults-backed configuration for Agentic Mode.
enum AgenticSettings {
    static let enabledKey = "AgenticModeEnabled"
    static let routerModelKey = "AgenticRouterModel"
    static let allowPromptKey = "AgenticAllowPromptSwitch"
    static let allowProfileKey = "AgenticAllowProfileSwitch"
    static let allowDeliveryKey = "AgenticAllowDelivery"
    static let allowAutosendKey = "AgenticAllowAutosend"
    static let allowOutputLanguageKey = "AgenticAllowOutputLanguage"

    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// Router model override; empty means "use the enhancement model".
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

/// What the router decided about the current dictation. All fields nil /
/// false mean "no directive found — behave exactly as without agentic mode".
struct AgenticDecision: Sendable {
    enum Delivery: String, Sendable {
        case paste
        case clipboardOnly = "clipboard_only"
    }

    enum Scope: String, Sendable {
        case thisDictation = "this_dictation"
        case session
    }

    var promptId: UUID?
    var profileId: UUID?
    var clearProfile: Bool = false
    var delivery: Delivery?
    var autoSend: AutoSendKey?
    var outputLanguage: String?
    var scope: Scope = .thisDictation
    var cleanedText: String?

    var hasActions: Bool {
        promptId != nil || profileId != nil || clearProfile
            || delivery != nil || autoSend != nil || outputLanguage != nil
    }

    var actionSummary: String {
        var parts: [String] = []
        if let promptId { parts.append("prompt=\(promptId.uuidString.prefix(8))") }
        if let profileId { parts.append("profile=\(profileId.uuidString.prefix(8))") }
        if clearProfile { parts.append("clear_profile") }
        if let delivery { parts.append("delivery=\(delivery.rawValue)") }
        if let autoSend { parts.append("autosend=\(autoSend.rawValue)") }
        if let outputLanguage { parts.append("output_language=\(outputLanguage)") }
        parts.append("scope=\(scope.rawValue)")
        return parts.joined(separator: ", ")
    }
}

/// Serializes the tool writes coming out of the agent loop.
actor AgenticDecisionCollector {
    private var decision = AgenticDecision()

    func setPrompt(_ id: UUID) { decision.promptId = id }
    func setProfile(_ id: UUID) { decision.profileId = id; decision.clearProfile = false }
    func clearProfile() { decision.clearProfile = true; decision.profileId = nil }
    func setDelivery(_ delivery: AgenticDecision.Delivery) { decision.delivery = delivery }
    func setAutoSend(_ key: AutoSendKey) { decision.autoSend = key }
    func setOutputLanguage(_ code: String) { decision.outputLanguage = code }
    func setScope(_ scope: AgenticDecision.Scope) { decision.scope = scope }

    func current() -> AgenticDecision { decision }
}

/// Snapshot of the catalogs the router may pick from. Plain values so the
/// tool closures stay Sendable.
struct AgenticCatalog: Sendable {
    struct PromptEntry: Sendable {
        let id: UUID
        let title: String
        let description: String
        let category: String
    }

    struct ProfileEntry: Sendable {
        let id: UUID
        let name: String
    }

    let prompts: [PromptEntry]
    let profiles: [ProfileEntry]
    let activePromptTitle: String
    let activeProfileName: String?

    var promptIds: Set<UUID> { Set(prompts.map(\.id)) }
    var profileIds: Set<UUID> { Set(profiles.map(\.id)) }
}

struct AgenticToolContext: ToolContext {
    let collector: AgenticDecisionCollector
}

// MARK: - Tool parameter payloads

private struct SelectPromptParams: Codable, SchemaProviding, Sendable {
    let prompt_id: String
}

private struct ActivateProfileParams: Codable, SchemaProviding, Sendable {
    /// A profile UUID from the catalog, or "none" to clear the active profile.
    let profile_id: String
}

private struct SetDeliveryParams: Codable, SchemaProviding, Sendable {
    /// "paste" or "clipboard_only"
    let mode: String
}

private struct SetAutosendParams: Codable, SchemaProviding, Sendable {
    /// "none", "enter", "shift_enter" or "command_enter"
    let key: String
}

private struct SetOutputLanguageParams: Codable, SchemaProviding, Sendable {
    /// BCP-47 code like "en" or "pt-BR", or "match" to follow the spoken language.
    let code: String
}

private struct SetScopeParams: Codable, SchemaProviding, Sendable {
    /// "this_dictation" (revert after this paste) or "session" (keep until changed)
    let scope: String
}

// MARK: - Router service

/// Phase-1 agentic router: one bounded AgentRunKit tool loop that interprets
/// spoken meta-directives ("isso aqui é um email formal", "só copia, não
/// cola"), records the requested reconfiguration, and returns the transcript
/// with the directives stripped. The pipeline applies the decision through
/// the allow-list and falls back to trigger words when the router abstains
/// or fails — agentic mode never blocks a dictation.
@MainActor
enum AgenticRouterService {
    private static let logger = Logger(subsystem: "agabo.dev.voiceink", category: "AgenticRouter")
    private static let timeoutSeconds: Double = 12

    struct Outcome {
        let decision: AgenticDecision
        let logStep: APICallLog.Step
    }

    static func route(
        text: String,
        enhancementService: AIEnhancementService,
        aiService: AIService
    ) async -> Outcome? {
        guard let client = makeClient(aiService: aiService) else {
            logger.notice("agentic: no compatible router client for provider \(aiService.selectedProvider.rawValue, privacy: .public)")
            return nil
        }

        let catalog = makeCatalog(enhancementService: enhancementService)
        let collector = AgenticDecisionCollector()
        let systemPrompt = makeSystemPrompt(catalog: catalog)
        let start = Date()

        let agent = Agent<AgenticToolContext>(
            client: client,
            tools: makeTools(catalog: catalog),
            configuration: AgentConfiguration(
                maxIterations: 6,
                toolTimeout: .seconds(5),
                systemPrompt: systemPrompt
            )
        )

        let runTask = Task {
            try await agent.run(
                userMessage: text,
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
            logger.notice("agentic: router failed/timed out: \(String(describing: error), privacy: .public)")
            return nil
        }

        var decision = await collector.current()
        decision = applyAllowList(to: decision)

        // Only trust the rewritten transcript when the router actually acted;
        // an abstaining router must leave the text untouched.
        if decision.hasActions,
           let content = result.content?.trimmingCharacters(in: .whitespacesAndNewlines),
           !content.isEmpty {
            decision.cleanedText = content
        }

        let durationMs = Int(Date().timeIntervalSince(start) * 1000)
        let step = APICallLog.Step(
            kind: .llm,
            provider: "Agentic Router (\(aiService.selectedProvider.rawValue))",
            model: effectiveModel(aiService: aiService),
            requestSummary: "agentic route, \(result.iterations) iteration(s)",
            requestSystemMessage: systemPrompt,
            requestUserMessage: text,
            responseSummary: decision.hasActions
                ? "actions: \(decision.actionSummary)\n---\n\(decision.cleanedText ?? text)"
                : "no directive found",
            durationMs: durationMs
        )
        logger.notice("agentic: \(decision.hasActions ? decision.actionSummary : "no directive", privacy: .public) in \(durationMs)ms")
        return Outcome(decision: decision, logStep: step)
    }

    // MARK: Client construction

    /// Builds an AgentRunKit client from the app's current enhancement
    /// provider + key. OpenAI-compatible providers strip the
    /// "chat/completions" suffix the app bakes into `baseURL`; Anthropic
    /// uses the native client; Local CLI has no HTTP surface, so agentic
    /// mode silently falls back to trigger words there.
    private static func makeClient(aiService: AIService) -> (any ToolCallSurfacingClient)? {
        let model = effectiveModel(aiService: aiService)
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
            return OpenAIClient(apiKey: aiService.apiKey, model: model, baseURL: url)
        }
    }

    private static func effectiveModel(aiService: AIService) -> String {
        let override = AgenticSettings.routerModel.trimmingCharacters(in: .whitespaces)
        return override.isEmpty ? aiService.currentModel : override
    }

    // MARK: Catalog + prompt

    private static func makeCatalog(enhancementService: AIEnhancementService) -> AgenticCatalog {
        let prompts = enhancementService.allPrompts.map {
            AgenticCatalog.PromptEntry(
                id: $0.id,
                title: $0.title,
                description: $0.description ?? "",
                category: $0.category.displayName
            )
        }
        let profiles = PowerModeManager.shared.configurations.map {
            AgenticCatalog.ProfileEntry(id: $0.id, name: "\($0.emoji) \($0.name)")
        }
        return AgenticCatalog(
            prompts: prompts,
            profiles: profiles,
            activePromptTitle: enhancementService.activePrompt?.title ?? "none",
            activeProfileName: PowerModeManager.shared.activeConfiguration.map { "\($0.emoji) \($0.name)" }
        )
    }

    private static func makeSystemPrompt(catalog: AgenticCatalog) -> String {
        let promptLines = catalog.prompts
            .map { "- \($0.id.uuidString) | \($0.title) [\($0.category)]\($0.description.isEmpty ? "" : " — \($0.description)")" }
            .joined(separator: "\n")
        let profileLines = catalog.profiles.isEmpty
            ? "(none configured)"
            : catalog.profiles.map { "- \($0.id.uuidString) | \($0.name)" }.joined(separator: "\n")

        return """
        You route dictation for a voice-typing app. The user message is a raw speech transcript (any language, often Portuguese or English). It may contain a META-DIRECTIVE: an instruction about how THIS dictation should be processed ("isso aqui é um email formal", "manda como mensagem informal pro Discord", "in English please", "só copia, não cola", "a partir de agora modo código").

        Your job:
        1. If — and only if — the transcript clearly contains such a meta-directive, call the matching tools to record the reconfiguration. Content that merely TALKS ABOUT email, chat, code, etc. is NOT a directive. When in doubt, call no tools.
        2. Directives that say "from now on" / "a partir de agora" → call set_scope with "session". Otherwise the default scope (this_dictation) already applies; activating a profile always implies session scope.
        3. Finish by returning ONLY the transcript with the spoken directive removed (fix capitalization at the seam). If you called no tools, return the transcript EXACTLY as received. Never answer the transcript's content, never add commentary.

        AVAILABLE PROMPTS (pick by id with select_prompt):
        \(promptLines)

        AVAILABLE PROFILES (pick by id with activate_profile; applies for the whole session):
        \(profileLines)

        CURRENT STATE: prompt = \(catalog.activePromptTitle); profile = \(catalog.activeProfileName ?? "none"); delivery = paste.
        """
    }

    // MARK: Tools

    private static func makeTools(catalog: AgenticCatalog) -> [any AnyTool<AgenticToolContext>] {
        let promptIds = catalog.promptIds
        let profileIds = catalog.profileIds

        let selectPrompt = try! Tool<SelectPromptParams, String, AgenticToolContext>(
            name: "select_prompt",
            description: "Use the given enhancement prompt (by UUID from AVAILABLE PROMPTS) for this dictation."
        ) { params, context in
            guard let id = UUID(uuidString: params.prompt_id), promptIds.contains(id) else {
                return "error: unknown prompt_id"
            }
            await context.collector.setPrompt(id)
            return "ok"
        }

        let activateProfile = try! Tool<ActivateProfileParams, String, AgenticToolContext>(
            name: "activate_profile",
            description: "Activate a profile (by UUID from AVAILABLE PROFILES) for the rest of the session, or pass \"none\" to clear the active profile."
        ) { params, context in
            if params.profile_id.lowercased() == "none" {
                await context.collector.clearProfile()
                await context.collector.setScope(.session)
                return "ok"
            }
            guard let id = UUID(uuidString: params.profile_id), profileIds.contains(id) else {
                return "error: unknown profile_id"
            }
            await context.collector.setProfile(id)
            await context.collector.setScope(.session)
            return "ok"
        }

        let setDelivery = try! Tool<SetDeliveryParams, String, AgenticToolContext>(
            name: "set_delivery",
            description: "How to deliver the result: \"paste\" (default — paste at cursor) or \"clipboard_only\" (copy without pasting)."
        ) { params, context in
            guard let delivery = AgenticDecision.Delivery(rawValue: params.mode.lowercased()) else {
                return "error: unknown mode"
            }
            await context.collector.setDelivery(delivery)
            return "ok"
        }

        let setAutosend = try! Tool<SetAutosendParams, String, AgenticToolContext>(
            name: "set_autosend",
            description: "Key to press automatically after pasting: \"none\", \"enter\", \"shift_enter\" or \"command_enter\"."
        ) { params, context in
            let normalized = params.key.lowercased().replacingOccurrences(of: "_", with: "")
            let key: AutoSendKey?
            switch normalized {
            case "none": key = AutoSendKey.none
            case "enter", "return": key = .enter
            case "shiftenter": key = .shiftEnter
            case "commandenter", "cmdenter": key = .commandEnter
            default: key = nil
            }
            guard let key else { return "error: unknown key" }
            await context.collector.setAutoSend(key)
            return "ok"
        }

        let setOutputLanguage = try! Tool<SetOutputLanguageParams, String, AgenticToolContext>(
            name: "set_output_language",
            description: "Language for the final text: a BCP-47 code like \"en\" or \"pt-BR\", or \"match\" to follow the spoken language."
        ) { params, context in
            let code = params.code.trimmingCharacters(in: .whitespaces)
            guard !code.isEmpty, code.count <= 10 else { return "error: bad code" }
            await context.collector.setOutputLanguage(code)
            return "ok"
        }

        let setScope = try! Tool<SetScopeParams, String, AgenticToolContext>(
            name: "set_scope",
            description: "\"this_dictation\" (default — revert after this paste) or \"session\" (keep the changes until switched again)."
        ) { params, context in
            guard let scope = AgenticDecision.Scope(rawValue: params.scope.lowercased()) else {
                return "error: unknown scope"
            }
            await context.collector.setScope(scope)
            return "ok"
        }

        return [selectPrompt, activateProfile, setDelivery, setAutosend, setOutputLanguage, setScope]
    }

    // MARK: Allow-list

    private static func applyAllowList(to decision: AgenticDecision) -> AgenticDecision {
        var result = decision
        if !AgenticSettings.isAllowed(AgenticSettings.allowPromptKey) { result.promptId = nil }
        if !AgenticSettings.isAllowed(AgenticSettings.allowProfileKey) {
            result.profileId = nil
            result.clearProfile = false
        }
        if !AgenticSettings.isAllowed(AgenticSettings.allowDeliveryKey) { result.delivery = nil }
        if !AgenticSettings.isAllowed(AgenticSettings.allowAutosendKey) { result.autoSend = nil }
        if !AgenticSettings.isAllowed(AgenticSettings.allowOutputLanguageKey) { result.outputLanguage = nil }
        return result
    }
}

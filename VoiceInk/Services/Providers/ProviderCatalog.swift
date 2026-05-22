import Combine
import Foundation

/// Read-only catalog over the union of STT (`ModelProvider`) and LLM
/// (`AIProvider`) registries. Powers the Providers tab: enumerates
/// providers, exposes capability metadata, and derives `isConfigured`
/// without coupling to either engine-side enum's storage shape.
///
/// Credential state is observed via `.aiProviderKeyChanged`: when a key
/// is added/removed anywhere in the app, `configurationRevision` bumps so
/// SwiftUI views re-render with up-to-date badges.
@MainActor
final class ProviderCatalog: ObservableObject {

    let entries: [ProviderEntry]
    @Published private(set) var configurationRevision: Int = 0

    private let aiService: AIService
    private var cancellables: Set<AnyCancellable> = []

    init(aiService: AIService) {
        self.aiService = aiService
        self.entries = Self.buildEntries()

        NotificationCenter.default.publisher(for: .aiProviderKeyChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.configurationRevision &+= 1
            }
            .store(in: &cancellables)
    }

    func entry(for id: ProviderID) -> ProviderEntry? {
        entries.first(where: { $0.id == id })
    }

    func providers(withCapability cap: ProviderCapability) -> [ProviderEntry] {
        entries.filter { $0.capabilities.contains(cap) }
    }

    /// `true` when the provider can be used today: either AIService reports it
    /// among `connectedProviders` (LLM-capable path) or — for STT-only
    /// providers — a Keychain entry exists.
    func isConfigured(_ entry: ProviderEntry) -> Bool {
        _ = configurationRevision
        if let aiRaw = entry.aiProviderRaw, let provider = AIProvider(rawValue: aiRaw) {
            return aiService.connectedProviders.contains(provider)
        }
        return APIKeyManager.shared.hasAPIKey(forProvider: entry.id.rawValue)
    }

    /// Notify observers that credential state changed for some provider.
    func markChanged() {
        configurationRevision &+= 1
    }

    private static func buildEntries() -> [ProviderEntry] {
        [
            .init(id: .anthropic,    displayName: "Anthropic",    capabilities: [.llm],
                  credentialKind: .apiKey, aiProviderRaw: "Anthropic", modelProviderRaw: nil,
                  signupURL: URL(string: "https://console.anthropic.com/settings/keys")),
            .init(id: .assemblyAI,   displayName: "AssemblyAI",   capabilities: [.stt, .llm],
                  credentialKind: .apiKey, aiProviderRaw: "AssemblyAI", modelProviderRaw: "AssemblyAI",
                  signupURL: URL(string: "https://www.assemblyai.com/dashboard/api-keys")),
            .init(id: .cartesia,     displayName: "Cartesia",     capabilities: [.stt],
                  credentialKind: .apiKey, aiProviderRaw: nil, modelProviderRaw: "Cartesia",
                  signupURL: URL(string: "https://play.cartesia.ai/")),
            .init(id: .cerebras,     displayName: "Cerebras",     capabilities: [.llm],
                  credentialKind: .apiKey, aiProviderRaw: "Cerebras", modelProviderRaw: nil,
                  signupURL: URL(string: "https://cloud.cerebras.ai/")),
            .init(id: .custom,       displayName: "Custom",       capabilities: [.llm],
                  credentialKind: .baseURLAndModel, aiProviderRaw: "Custom", modelProviderRaw: nil,
                  signupURL: nil),
            .init(id: .deepgram,     displayName: "Deepgram",     capabilities: [.stt, .llm],
                  credentialKind: .apiKey, aiProviderRaw: "Deepgram", modelProviderRaw: "Deepgram",
                  signupURL: URL(string: "https://console.deepgram.com/api-keys")),
            .init(id: .elevenLabs,   displayName: "ElevenLabs",   capabilities: [.stt, .llm],
                  credentialKind: .apiKey, aiProviderRaw: "ElevenLabs", modelProviderRaw: "ElevenLabs",
                  signupURL: URL(string: "https://elevenlabs.io/speech-synthesis")),
            .init(id: .gemini,       displayName: "Gemini",       capabilities: [.stt, .llm],
                  credentialKind: .apiKey, aiProviderRaw: "Gemini", modelProviderRaw: "Gemini",
                  signupURL: URL(string: "https://makersuite.google.com/app/apikey")),
            .init(id: .groq,         displayName: "Groq",         capabilities: [.stt, .llm],
                  credentialKind: .apiKey, aiProviderRaw: "Groq", modelProviderRaw: "Groq",
                  signupURL: URL(string: "https://console.groq.com/keys")),
            .init(id: .localCLI,     displayName: "Local CLI",    capabilities: [.llm],
                  credentialKind: .commandTemplate, aiProviderRaw: "Local CLI", modelProviderRaw: nil,
                  signupURL: nil),
            .init(id: .mistral,      displayName: "Mistral",      capabilities: [.stt, .llm],
                  credentialKind: .apiKey, aiProviderRaw: "Mistral", modelProviderRaw: "Mistral",
                  signupURL: URL(string: "https://console.mistral.ai/api-keys")),
            .init(id: .ollama,       displayName: "Ollama",       capabilities: [.llm],
                  credentialKind: .baseURL, aiProviderRaw: "Ollama", modelProviderRaw: nil,
                  signupURL: URL(string: "https://ollama.com/download")),
            .init(id: .openAI,       displayName: "OpenAI",       capabilities: [.llm],
                  credentialKind: .apiKey, aiProviderRaw: "OpenAI", modelProviderRaw: nil,
                  signupURL: URL(string: "https://platform.openai.com/api-keys")),
            .init(id: .openRouter,   displayName: "OpenRouter",   capabilities: [.llm],
                  credentialKind: .apiKey, aiProviderRaw: "OpenRouter", modelProviderRaw: nil,
                  signupURL: URL(string: "https://openrouter.ai/keys")),
            .init(id: .soniox,       displayName: "Soniox",       capabilities: [.stt, .llm],
                  credentialKind: .apiKey, aiProviderRaw: "Soniox", modelProviderRaw: "Soniox",
                  signupURL: URL(string: "https://console.soniox.com/")),
            .init(id: .speechmatics, displayName: "Speechmatics", capabilities: [.stt, .llm],
                  credentialKind: .apiKey, aiProviderRaw: "Speechmatics", modelProviderRaw: "Speechmatics",
                  signupURL: URL(string: "https://portal.speechmatics.com/manage-access/")),
            .init(id: .xai,          displayName: "xAI",          capabilities: [.stt, .llm],
                  credentialKind: .apiKey, aiProviderRaw: "xAI", modelProviderRaw: "xAI",
                  signupURL: URL(string: "https://console.x.ai/")),
        ]
    }
}

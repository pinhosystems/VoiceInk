import Combine
import Foundation

/// Read-only catalog over every provider VoiceInk integrates with — cloud
/// LLM/STT services plus local on-device STT engines (Whisper, Parakeet,
/// Native Apple). Powers the Providers tab: enumerates providers, exposes
/// capability + category metadata, and derives `isConfigured` without
/// coupling to any engine-side enum's storage shape.
///
/// Credential / installation state is observed via three streams:
///   - `.aiProviderKeyChanged` — cloud API key add/remove
///   - `whisperModelManager.$availableModels` — Whisper .bin files
///   - `fluidAudioModelManager.$downloadStatuses` (proxy) — Parakeet model
///
/// Each stream bumps `configurationRevision` so SwiftUI re-renders the
/// configured badges in real time.
@MainActor
final class ProviderCatalog: ObservableObject {

    let entries: [ProviderEntry]
    @Published private(set) var configurationRevision: Int = 0

    private let aiService: AIService
    private let whisperModelManager: WhisperModelManager
    private let fluidAudioModelManager: FluidAudioModelManager
    private var cancellables: Set<AnyCancellable> = []

    init(aiService: AIService,
         whisperModelManager: WhisperModelManager,
         fluidAudioModelManager: FluidAudioModelManager) {
        self.aiService = aiService
        self.whisperModelManager = whisperModelManager
        self.fluidAudioModelManager = fluidAudioModelManager
        self.entries = Self.buildEntries()

        NotificationCenter.default.publisher(for: .aiProviderKeyChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.configurationRevision &+= 1 }
            .store(in: &cancellables)

        whisperModelManager.$availableModels
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.configurationRevision &+= 1 }
            .store(in: &cancellables)

        // FluidAudioModelManager publishes its own state via objectWillChange
        // (download status dict is private). Subscribe to that.
        fluidAudioModelManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.configurationRevision &+= 1 }
            .store(in: &cancellables)
    }

    func entry(for id: ProviderID) -> ProviderEntry? {
        entries.first(where: { $0.id == id })
    }

    func providers(withCapability cap: ProviderCapability) -> [ProviderEntry] {
        entries.filter { $0.capabilities.contains(cap) }
    }

    func providers(in category: ProviderCategory) -> [ProviderEntry] {
        entries.filter { $0.category == category }
    }

    /// `true` when the provider can be used today.
    ///   - cloud + apiKey: a Keychain entry exists OR (LLM-capable path)
    ///     AIService reports it as connected.
    ///   - Ollama: connected.
    ///   - Local CLI: command template set.
    ///   - Custom: URL + model + key all set.
    ///   - Whisper: at least one ggml model downloaded or imported.
    ///   - Parakeet: at least one Parakeet variant downloaded.
    ///   - Native Apple: always true (built into the OS).
    func isConfigured(_ entry: ProviderEntry) -> Bool {
        _ = configurationRevision
        switch entry.credentialKind {
        case .localModels:
            return isLocalInstalled(entry)
        case .builtIn:
            return true
        case .apiKey, .baseURL, .commandTemplate, .baseURLAndModel:
            if let aiRaw = entry.aiProviderRaw, let provider = AIProvider(rawValue: aiRaw) {
                return aiService.connectedProviders.contains(provider)
            }
            return APIKeyManager.shared.hasAPIKey(forProvider: entry.id.rawValue)
        }
    }

    /// Notify observers that credential state changed for some provider.
    func markChanged() {
        configurationRevision &+= 1
    }

    private func isLocalInstalled(_ entry: ProviderEntry) -> Bool {
        switch entry.id {
        case .whisper:
            return !whisperModelManager.availableModels.isEmpty
        case .fluidAudio:
            // Any Parakeet variant counts as "installed" once it has been
            // downloaded. FluidAudio tracks per-model download status; the
            // simplest proxy is checking if the per-model directory exists.
            return Self.anyParakeetInstalled()
        default:
            return false
        }
    }

    private static func anyParakeetInstalled() -> Bool {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return false
        }
        let modelsDir = appSupport
            .appendingPathComponent("com.prakashjoshipax.VoiceInk")
            .appendingPathComponent("FluidAudio", isDirectory: true)
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: modelsDir.path, isDirectory: &isDir), isDir.boolValue else {
            return false
        }
        let contents = (try? fm.contentsOfDirectory(atPath: modelsDir.path)) ?? []
        return !contents.isEmpty
    }

    private static func buildEntries() -> [ProviderEntry] {
        [
            // MARK: - Local on-device STT
            .init(id: .whisper, displayName: "Whisper", category: .local,
                  capabilities: [.stt], credentialKind: .localModels,
                  aiProviderRaw: nil, modelProviderRaw: "Whisper",
                  signupURL: URL(string: "https://github.com/ggerganov/whisper.cpp"),
                  summary: "OpenAI Whisper running locally via whisper.cpp. Pick a model size that fits your machine.",
                  iconSystemName: "cpu"),
            .init(id: .fluidAudio, displayName: "Parakeet", category: .local,
                  capabilities: [.stt], credentialKind: .localModels,
                  aiProviderRaw: nil, modelProviderRaw: "Parakeet",
                  signupURL: URL(string: "https://github.com/FluidInference/FluidAudio"),
                  summary: "NVIDIA Parakeet via FluidAudio. Fast on-device transcription with English (V2) or multilingual (V3) support.",
                  iconSystemName: "bolt.fill"),
            .init(id: .nativeApple, displayName: "Native Apple", category: .local,
                  capabilities: [.stt], credentialKind: .builtIn,
                  aiProviderRaw: nil, modelProviderRaw: "Native Apple",
                  signupURL: nil,
                  summary: "Apple's built-in Speech framework. Requires macOS 26.",
                  iconSystemName: "applelogo"),

            // MARK: - Local LLM hosts
            .init(id: .ollama, displayName: "Ollama", category: .local,
                  capabilities: [.llm], credentialKind: .baseURL,
                  aiProviderRaw: "Ollama", modelProviderRaw: nil,
                  signupURL: URL(string: "https://ollama.com/download"),
                  summary: "Self-hosted LLM server. Point VoiceInk at any Ollama instance for offline enhancement.",
                  iconSystemName: "server.rack"),
            // Local CLI providers are user-defined and live in
            // `LocalCLIProviderManager`; the Providers tab renders each as
            // its own card alongside the static catalog (same pattern as
            // CustomProvider). Intentionally absent from this static list.

            // MARK: - Cloud providers
            .init(id: .anthropic, displayName: "Anthropic", category: .cloud,
                  capabilities: [.llm], credentialKind: .apiKey,
                  aiProviderRaw: "Anthropic", modelProviderRaw: nil,
                  signupURL: URL(string: "https://console.anthropic.com/settings/keys"),
                  summary: "Claude models. High-quality LLM enhancement.",
                  iconSystemName: "sparkles"),
            .init(id: .assemblyAI, displayName: "AssemblyAI", category: .cloud,
                  capabilities: [.stt, .llm], credentialKind: .apiKey,
                  aiProviderRaw: "AssemblyAI", modelProviderRaw: "AssemblyAI",
                  signupURL: URL(string: "https://www.assemblyai.com/dashboard/api-keys"),
                  summary: "Speech-to-text with optional LLM endpoints.",
                  iconSystemName: "waveform"),
            .init(id: .cartesia, displayName: "Cartesia", category: .cloud,
                  capabilities: [.stt], credentialKind: .apiKey,
                  aiProviderRaw: nil, modelProviderRaw: "Cartesia",
                  signupURL: URL(string: "https://play.cartesia.ai/"),
                  summary: "Low-latency streaming speech-to-text.",
                  iconSystemName: "waveform"),
            .init(id: .cerebras, displayName: "Cerebras", category: .cloud,
                  capabilities: [.llm], credentialKind: .apiKey,
                  aiProviderRaw: "Cerebras", modelProviderRaw: nil,
                  signupURL: URL(string: "https://cloud.cerebras.ai/"),
                  summary: "Cerebras inference for open-weight LLMs.",
                  iconSystemName: "sparkles"),
            .init(id: .deepgram, displayName: "Deepgram", category: .cloud,
                  capabilities: [.stt, .llm], credentialKind: .apiKey,
                  aiProviderRaw: "Deepgram", modelProviderRaw: "Deepgram",
                  signupURL: URL(string: "https://console.deepgram.com/api-keys"),
                  summary: "Deepgram speech-to-text with batch and streaming.",
                  iconSystemName: "waveform"),
            .init(id: .elevenLabs, displayName: "ElevenLabs", category: .cloud,
                  capabilities: [.stt], credentialKind: .apiKey,
                  aiProviderRaw: "ElevenLabs", modelProviderRaw: "ElevenLabs",
                  signupURL: URL(string: "https://elevenlabs.io/speech-synthesis"),
                  summary: "Scribe transcription models.",
                  iconSystemName: "waveform"),
            .init(id: .gemini, displayName: "Gemini", category: .cloud,
                  capabilities: [.stt, .llm], credentialKind: .apiKey,
                  aiProviderRaw: "Gemini", modelProviderRaw: "Gemini",
                  signupURL: URL(string: "https://makersuite.google.com/app/apikey"),
                  summary: "Google Gemini for transcription and LLM enhancement.",
                  iconSystemName: "sparkles"),
            .init(id: .groq, displayName: "Groq", category: .cloud,
                  capabilities: [.stt, .llm], credentialKind: .apiKey,
                  aiProviderRaw: "Groq", modelProviderRaw: "Groq",
                  signupURL: URL(string: "https://console.groq.com/keys"),
                  summary: "Groq's LPU inference for fast Whisper and chat models.",
                  iconSystemName: "bolt.fill"),
            .init(id: .mistral, displayName: "Mistral", category: .cloud,
                  capabilities: [.stt, .llm], credentialKind: .apiKey,
                  aiProviderRaw: "Mistral", modelProviderRaw: "Mistral",
                  signupURL: URL(string: "https://console.mistral.ai/api-keys"),
                  summary: "Mistral models for transcription and enhancement.",
                  iconSystemName: "sparkles"),
            .init(id: .openAI, displayName: "OpenAI", category: .cloud,
                  capabilities: [.llm], credentialKind: .apiKey,
                  aiProviderRaw: "OpenAI", modelProviderRaw: nil,
                  signupURL: URL(string: "https://platform.openai.com/api-keys"),
                  summary: "GPT models for LLM enhancement.",
                  iconSystemName: "sparkles"),
            .init(id: .openRouter, displayName: "OpenRouter", category: .cloud,
                  capabilities: [.llm], credentialKind: .apiKey,
                  aiProviderRaw: "OpenRouter", modelProviderRaw: nil,
                  signupURL: URL(string: "https://openrouter.ai/keys"),
                  summary: "Unified gateway to many LLM providers.",
                  iconSystemName: "sparkles"),
            .init(id: .soniox, displayName: "Soniox", category: .cloud,
                  capabilities: [.stt, .llm], credentialKind: .apiKey,
                  aiProviderRaw: "Soniox", modelProviderRaw: "Soniox",
                  signupURL: URL(string: "https://console.soniox.com/"),
                  summary: "Soniox real-time speech-to-text.",
                  iconSystemName: "waveform"),
            .init(id: .speechmatics, displayName: "Speechmatics", category: .cloud,
                  capabilities: [.stt, .llm], credentialKind: .apiKey,
                  aiProviderRaw: "Speechmatics", modelProviderRaw: "Speechmatics",
                  signupURL: URL(string: "https://portal.speechmatics.com/manage-access/"),
                  summary: "Speechmatics enhanced transcription.",
                  iconSystemName: "waveform"),
            .init(id: .xai, displayName: "xAI", category: .cloud,
                  capabilities: [.stt, .llm], credentialKind: .apiKey,
                  aiProviderRaw: "xAI", modelProviderRaw: "xAI",
                  signupURL: URL(string: "https://console.x.ai/"),
                  summary: "Grok speech-to-text (streaming + REST) and chat models.",
                  iconSystemName: "sparkles"),

            // Custom providers are user-defined and live in
            // `CustomProviderManager`; the Providers tab renders each as its
            // own card alongside the static catalog. They are intentionally
            // absent from this static list.
        ]
    }
}

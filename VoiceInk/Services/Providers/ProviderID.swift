import Foundation

/// Stable identifier for a third-party provider VoiceInk integrates with.
/// Union of `ModelProvider` (STT) and `AIProvider` (LLM): some providers
/// offer one capability, several offer both.
///
/// `rawValue` is the human-readable label shown in the Providers tab and is
/// also passed to `APIKeyManager` (which internally lower-cases and maps to
/// a Keychain identifier).
enum ProviderID: String, CaseIterable, Hashable, Codable, Identifiable {
    case anthropic = "Anthropic"
    case assemblyAI = "AssemblyAI"
    case cartesia = "Cartesia"
    case cerebras = "Cerebras"
    case custom = "Custom"
    case deepgram = "Deepgram"
    case elevenLabs = "ElevenLabs"
    case fluidAudio = "Parakeet"
    case gemini = "Gemini"
    case groq = "Groq"
    case localCLI = "Local CLI"
    case mistral = "Mistral"
    case nativeApple = "Native Apple"
    case ollama = "Ollama"
    case openAI = "OpenAI"
    case openRouter = "OpenRouter"
    case soniox = "Soniox"
    case speechmatics = "Speechmatics"
    case whisper = "Whisper"
    case xai = "xAI"

    var id: String { rawValue }
}

/// Where the provider's compute happens. Drives the Providers tab filter
/// pills and the visual treatment of each card.
enum ProviderCategory: String, CaseIterable, Hashable, Identifiable {
    case local = "Local"
    case cloud = "Cloud"
    case custom = "Custom"

    var id: String { rawValue }
}

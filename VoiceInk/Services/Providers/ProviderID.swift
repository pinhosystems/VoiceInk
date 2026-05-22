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
    case gemini = "Gemini"
    case groq = "Groq"
    case localCLI = "Local CLI"
    case mistral = "Mistral"
    case ollama = "Ollama"
    case openAI = "OpenAI"
    case openRouter = "OpenRouter"
    case soniox = "Soniox"
    case speechmatics = "Speechmatics"
    case xai = "xAI"

    var id: String { rawValue }
}

import Foundation

/// User-defined provider that points VoiceInk at any OpenAI-compatible
/// endpoint. A single record can opt into STT (chat completions-shape
/// transcription endpoint), LLM (chat completions endpoint), or both.
///
/// Stored persistently by `CustomProviderManager`. The API key lives in
/// the Keychain under the same identifier as the legacy `CustomCloudModel`
/// (`customModel_<UUID>_APIKey`), so the existing STT pipeline keeps
/// finding it without changes.
struct CustomProvider: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var summary: String

    var offersSTT: Bool
    var offersLLM: Bool

    /// Full transcription endpoint URL, e.g. `https://api.openai.com/v1/audio/transcriptions`.
    var sttEndpointURL: String
    /// STT model identifier the endpoint expects, e.g. `whisper-1`.
    var sttModelName: String
    /// When true the STT model is advertised as multilingual; otherwise the
    /// language selector locks to English-only — same semantics as the
    /// existing `CustomCloudModel`.
    var isMultilingual: Bool
    /// Reserved for future streaming-capable customs; not consumed yet.
    var supportsStreaming: Bool

    /// Full chat completions endpoint URL,
    /// e.g. `https://api.openai.com/v1/chat/completions`.
    var llmEndpointURL: String
    /// LLM model identifier the endpoint expects, e.g. `gpt-5.4`.
    var llmModelName: String

    init(
        id: UUID = UUID(),
        name: String,
        summary: String = "",
        offersSTT: Bool = false,
        offersLLM: Bool = false,
        sttEndpointURL: String = "",
        sttModelName: String = "",
        isMultilingual: Bool = true,
        supportsStreaming: Bool = false,
        llmEndpointURL: String = "",
        llmModelName: String = ""
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.offersSTT = offersSTT
        self.offersLLM = offersLLM
        self.sttEndpointURL = sttEndpointURL
        self.sttModelName = sttModelName
        self.isMultilingual = isMultilingual
        self.supportsStreaming = supportsStreaming
        self.llmEndpointURL = llmEndpointURL
        self.llmModelName = llmModelName
    }

    var capabilities: Set<ProviderCapability> {
        var set: Set<ProviderCapability> = []
        if offersSTT { set.insert(.stt) }
        if offersLLM { set.insert(.llm) }
        return set
    }
}

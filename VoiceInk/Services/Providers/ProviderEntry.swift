import Foundation

/// Shape of credential input required to configure a provider in the
/// Providers tab.
enum ProviderCredentialKind {
    /// Standard API key against a fixed endpoint (most cloud providers).
    case apiKey
    /// Base URL only (Ollama: local server, no API key).
    case baseURL
    /// Free-form command template (Local CLI: shell out to a binary).
    case commandTemplate
    /// Base URL + model name + API key (Custom OpenAI-compatible provider).
    case baseURLAndModel
    /// On-device models that ship as downloadable binaries (Whisper, Parakeet).
    case localModels
    /// Built-in OS capability that needs no installation (Native Apple Speech).
    case builtIn
}

/// Metadata describing a single provider for the Providers tab.
///
/// `aiProviderRaw` and `modelProviderRaw` are the engine-side enum raw
/// values used to look up `AIProvider` (LLM enhancement) and `ModelProvider`
/// (STT) entries — kept as raw strings so this file does not depend on
/// either enum's storage shape changing.
struct ProviderEntry: Identifiable, Hashable {
    let id: ProviderID
    let displayName: String
    let category: ProviderCategory
    let capabilities: Set<ProviderCapability>
    let credentialKind: ProviderCredentialKind
    let aiProviderRaw: String?
    let modelProviderRaw: String?
    let signupURL: URL?
    let summary: String
    let iconSystemName: String

    static func == (lhs: ProviderEntry, rhs: ProviderEntry) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

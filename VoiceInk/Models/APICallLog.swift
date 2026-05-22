import Foundation

/// Per-Transcription troubleshooting fixture. Captures one entry per
/// outbound API call (STT cloud, STT local, LLM cloud, Local CLI) so the
/// detail view can show what was sent / what came back without the user
/// having to rerun anything.
///
/// Stored on `Transcription.troubleshootingLogJSON` as a JSON blob.
///
/// **Token redaction is by omission**: this model never stores API keys
/// or `Authorization` headers — the capture sites only forward assembled
/// payload bodies (system / user messages, endpoint URL host, model
/// name, response text). Bearer tokens are never inserted, so there is
/// nothing to redact at write time.
struct APICallLog: Codable, Hashable {

    /// What kind of API call this entry describes.
    enum Kind: String, Codable {
        case stt
        case llm
        case localCLI
    }

    struct Step: Codable, Hashable, Identifiable {
        var id = UUID()
        var kind: Kind
        var provider: String
        var providerVariant: String?    // e.g. "Cloud" vs "Local"
        var endpointHost: String?       // host only — never full URL with secrets
        var model: String?
        var languageCode: String?
        var requestSummary: String?     // STT: "audio, 24s, mono"; LLM: system + user
        var requestSystemMessage: String?
        var requestUserMessage: String?
        var responseSummary: String?    // STT transcript, LLM completion, CLI stdout
        var durationMs: Int?
        var errorMessage: String?
        var timestamp: Date = Date()

        private enum CodingKeys: String, CodingKey {
            case id, kind, provider, providerVariant, endpointHost, model,
                 languageCode, requestSummary, requestSystemMessage,
                 requestUserMessage, responseSummary, durationMs,
                 errorMessage, timestamp
        }
    }

    var steps: [Step] = []

    // MARK: - JSON helpers

    func encoded() -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decoded(from json: String?) -> APICallLog? {
        guard let json = json,
              let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(APICallLog.self, from: data)
    }

    /// Best-effort host extraction so the log never carries query strings
    /// or path segments that might contain identifiers.
    static func host(from url: String) -> String? {
        guard let url = URL(string: url), let host = url.host else { return nil }
        return host
    }
}

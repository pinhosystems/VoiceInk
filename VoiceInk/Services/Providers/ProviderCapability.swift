import Foundation

/// The transcription/enhancement capabilities a provider exposes to VoiceInk.
enum ProviderCapability: String, CaseIterable, Hashable, Comparable {
    case stt = "STT"
    case llm = "LLM"

    var displayName: String { rawValue }

    static func < (lhs: ProviderCapability, rhs: ProviderCapability) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

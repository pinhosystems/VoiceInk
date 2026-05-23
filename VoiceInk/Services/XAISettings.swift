import Foundation

/// Centralizes UserDefaults keys + defaults for xAI STT tuning. Keeping the
/// keys in one place avoids drift between the Settings view, the REST
/// provider, and the streaming provider — all three need to agree on the
/// stored representation.
///
/// Scope is intentionally narrow: only `endpointing` (a dictation-impacting
/// bug knob) and `format` (numbers/dates ITN) are exposed. `filler_words`
/// is handled by VoiceInk's own `FillerWordManager` pipeline downstream,
/// `diarize` is meaningless for single-speaker dictation, and
/// `multichannel` would alter the response shape and break parsing.
enum XAISettings {
    enum Key {
        static let endpointingMs = "XAISTT.endpointingMs"
        static let format = "XAISTT.format"
    }

    /// Silence (ms) before the streaming endpoint declares an utterance
    /// final. xAI's documented range is 0-5000. 1500 is comfortable for
    /// dictation with natural thinking pauses while keeping interactive
    /// latency low.
    static let defaultEndpointingMs = 1500

    /// REST formatting (numbers, dates, ITN). Was hard-coded `true` before
    /// this preference existed; keep the default to preserve behavior for
    /// existing installs.
    static let defaultFormat = true

    /// Always request fillers from xAI so VoiceInk's `FillerWordManager`
    /// owns the user-visible filler behavior. Otherwise the server would
    /// silently strip and the in-app setting would be a no-op for xAI.
    static let keepFillerWords = true

    static var endpointingMs: Int {
        let stored = UserDefaults.standard.integer(forKey: Key.endpointingMs)
        // `integer(forKey:)` returns 0 when missing, which is also a valid
        // user value ("commit on any pause"). Differentiate via `object(forKey:)`.
        guard UserDefaults.standard.object(forKey: Key.endpointingMs) != nil else {
            return defaultEndpointingMs
        }
        return max(0, min(5000, stored))
    }

    static var format: Bool {
        guard UserDefaults.standard.object(forKey: Key.format) != nil else {
            return defaultFormat
        }
        return UserDefaults.standard.bool(forKey: Key.format)
    }
}

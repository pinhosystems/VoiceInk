import Foundation

/// Pushes a new `DefaultAppLanguage` choice into every per-context language
/// UserDefault (STT, LLM output) using `LanguageFallbackResolver` so a
/// regional variant the context does not expose collapses to the closest
/// available match — typically the generic primary subtag.
///
/// Lives in a standalone enum so the onboarding language step and the
/// Settings → Language section can share the exact same propagation logic
/// without coupling either view to the other's lifecycle.
enum LanguageDefaultPropagator {

    /// Hard-coded mirror of `EnhancementLocaleSection.outputLanguageOptions`.
    /// Keeping it here lets the propagator resolve LLM output language
    /// without importing the SwiftUI component.
    static let llmOutputLanguageCodes: [String] = [
        "en", "pt-BR", "pt-PT", "es", "fr", "de", "it", "ja", "ko", "zh"
    ]

    /// Applies `newDefault` to every downstream language UserDefault.
    ///
    /// - Parameters:
    ///   - newDefault: BCP-47 code chosen by the user (e.g. "pt-BR").
    ///   - sttModelLanguages: BCP-47 codes the currently-selected transcription
    ///     model accepts. Pass nil/empty when no model is loaded yet (e.g.
    ///     during onboarding before the model picker runs); the helper then
    ///     stores the raw target so the eventual model picks it up via its
    ///     own validation path.
    ///   - sttValidator: Provider-specific final validation, typically
    ///     `TranscriptionLanguageSupport.validLanguageOrFallback(_:for:)`.
    ///     Pass nil to skip — useful in onboarding or unit tests where the
    ///     model manager isn't reachable.
    @MainActor
    static func apply(
        _ newDefault: String,
        sttModelLanguages: [String]? = nil,
        sttValidator: ((String) -> String)? = nil
    ) {
        let trimmed = newDefault.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // STT: resolve against the model's supported list (when known),
        // then run through the provider-specific validator for Apple Native
        // vs. Whisper vs. FluidAudio quirks.
        let resolvedSTT = LanguageFallbackResolver.resolve(
            target: trimmed,
            available: sttModelLanguages ?? [],
            fallback: trimmed
        )
        let finalSTT = sttValidator.map { $0(resolvedSTT) } ?? resolvedSTT
        UserDefaults.standard.set(finalSTT, forKey: "SelectedLanguage")

        // LLM output: fall back to the `match` sentinel when no representative
        // entry exists so the LLM mirrors the STT language instead of
        // silently translating into an unrelated locale.
        if let llmMatch = LanguageFallbackResolver.resolve(
            target: trimmed,
            available: llmOutputLanguageCodes
        ) {
            UserDefaults.standard.set(llmMatch, forKey: LocalePackRegistry.outputLanguageKey)
        } else {
            UserDefaults.standard.set(
                LocalePackRegistry.outputLanguageMatchSentinel,
                forKey: LocalePackRegistry.outputLanguageKey
            )
        }

        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
}

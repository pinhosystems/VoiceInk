import Foundation

/// Runtime resolver for the STT language. Bridges the "default" sentinel
/// used by the AI Models picker (and any other surface that wants to defer
/// to Settings → Default language) into a concrete BCP-47 code that an STT
/// engine can consume.
///
/// Design:
/// - `SelectedLanguage` stores either an explicit BCP-47 code (the user
///   customized the choice in AI Models) OR the sentinel value
///   `LanguageResolver.defaultSentinel` ("default") meaning "use whatever
///   Settings → Default language is right now".
/// - The sentinel is resolved live at every call site, never persisted as
///   a concrete value. A change in Settings instantly affects every
///   "default"-bound surface without rewriting their stored value.
/// - When a model exposes a limited set of supported languages, the
///   resolver can be asked to validate the resolved code against that set
///   and fall back gracefully (`auto` if the model supports it, else the
///   first supported entry, else the unmodified resolved code).
///
/// Compare to `LocalePackRegistry.outputLanguageCode(sttCode:)` which
/// resolves the LLM-side "match" sentinel by walking through whatever the
/// STT resolved to — together the two sentinels form the inheritance
/// chain Settings → STT → LLM.
enum LanguageResolver {
    /// Sentinel value stored in `SelectedLanguage` when the user wants the
    /// STT picker to inherit from Settings → Default language.
    static let defaultSentinel = "default"

    /// UserDefaults key for the raw STT language value (sentinel or BCP-47).
    static let sttLanguageKey = "SelectedLanguage"

    /// UserDefaults key for the global default language driven by Settings.
    static let defaultAppLanguageKey = "DefaultAppLanguage"

    /// Raw value stored under `SelectedLanguage` — sentinel or BCP-47.
    /// Use when you need to preserve user intent (session baseline capture,
    /// export, picker bindings). Use `effectiveSTTCode(...)` instead for
    /// any runtime decision that needs a concrete language code.
    static func rawSTTValue() -> String? {
        UserDefaults.standard.string(forKey: sttLanguageKey)
    }

    /// True when the stored STT value is the inherit-from-Settings sentinel.
    static func isUsingDefaultSentinel() -> Bool {
        let raw = (UserDefaults.standard.string(forKey: sttLanguageKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return raw == defaultSentinel
    }

    /// Current Settings → Default language. Falls back to "en" when no
    /// value has been registered yet (registerDefaults runs at startup so
    /// this is normally unreachable).
    static func settingsDefaultLanguage() -> String {
        UserDefaults.standard.string(forKey: defaultAppLanguageKey) ?? "en"
    }

    /// The concrete BCP-47 code STT should use right now.
    ///
    /// - When `SelectedLanguage` is the `"default"` sentinel (or empty/nil),
    ///   resolves through Settings → Default language.
    /// - When `SelectedLanguage` is any other string, returns it verbatim —
    ///   the user explicitly customized.
    /// - `modelLanguages`, when supplied, is used to coerce the resolved
    ///   code into something the active model actually supports via
    ///   `LanguageFallbackResolver.resolve(target:available:fallback:)`.
    ///   Pass `nil` to skip model validation (e.g. when reading for a
    ///   non-model context like the FillerWordManager).
    static func effectiveSTTCode(modelLanguages: [String]? = nil) -> String? {
        let stored = (UserDefaults.standard.string(forKey: sttLanguageKey) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let raw: String
        if stored.isEmpty || stored.lowercased() == defaultSentinel {
            raw = settingsDefaultLanguage()
        } else {
            raw = stored
        }
        guard !raw.isEmpty else { return nil }
        if let available = modelLanguages, !available.isEmpty {
            return LanguageFallbackResolver.resolve(
                target: raw,
                available: available,
                fallback: raw
            )
        }
        return raw
    }

    /// Concrete STT code with a non-optional fallback string for callers
    /// that historically used `?? "auto"` or `?? "en"`. Centralizes that
    /// fallback so the few legacy sites don't each pick their own default.
    static func effectiveSTTCode(
        modelLanguages: [String]? = nil,
        fallback: String
    ) -> String {
        effectiveSTTCode(modelLanguages: modelLanguages) ?? fallback
    }

    /// Convenience: true when the resolved STT code is the engine
    /// auto-detect tag. Some STT providers need the literal `"auto"` to
    /// trigger detection; others omit the language field entirely. Callers
    /// use this to decide which path to take.
    static func resolvedIsAutoDetect(modelLanguages: [String]? = nil) -> Bool {
        guard let code = effectiveSTTCode(modelLanguages: modelLanguages) else {
            return false
        }
        return code.lowercased() == "auto"
    }

    /// Model-aware variant. Resolves the sentinel into a concrete code
    /// then walks the full fallback chain so the result is guaranteed to
    /// be one the model actually accepts.
    ///
    /// Resolution order (most-specific to least-specific):
    ///   1. Exact match — `pt-BR` stays `pt-BR` when the model supports
    ///      `pt-BR` directly.
    ///   2. Generic primary-subtag — `pt-BR` collapses to `pt` when the
    ///      model only ships the region-less code. Same for `en-AU` → `en`.
    ///   3. Sibling region — `pt` promotes to `pt-BR` when the model
    ///      ships only regioned variants. Pick is whatever the model
    ///      exposes first; for Apple Native the provider-aware path below
    ///      uses curated defaults (`pt` → `pt-BR`, `en` → `en-US`, ...).
    ///   4. `auto` — fall back to engine auto-detect when the model
    ///      exposes that tag.
    ///   5. Provider-specific safety net — last resort goes through
    ///      `TranscriptionLanguageSupport.validLanguageOrFallback`, which
    ///      ultimately returns `en` or the first key when nothing else
    ///      matches. There is no clean recovery when a model exposes
    ///      none of these — the API call will reject the language.
    ///
    /// Apple Native gets the provider-aware path directly because its
    /// BCP-47 dictionary needs the curated `mapToAppleNative` defaults
    /// (e.g. `pt` should prefer `pt-BR` over `pt-PT`, not whatever the
    /// dictionary iterates first).
    static func effectiveSTTCode(for model: any TranscriptionModel) -> String {
        let base = effectiveSTTCode() ?? settingsDefaultLanguage()

        if model.provider == .nativeApple {
            return TranscriptionLanguageSupport.validLanguageOrFallback(base, for: model)
        }

        let modelLanguages = Array(TranscriptionLanguageSupport.languages(for: model).keys)
        if let resolved = LanguageFallbackResolver.resolve(target: base, available: modelLanguages) {
            return resolved
        }
        // No exact / generic / sibling / auto match in the model's set —
        // hand to the provider-aware fallback which at least returns
        // "en" or the first available key rather than nil.
        return TranscriptionLanguageSupport.validLanguageOrFallback(base, for: model)
    }
}

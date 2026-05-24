import Foundation

enum AppDefaults {
    /// Locale-aware default for SelectedLanguage. Used only as the registered
    /// default — once the user explicitly picks a language, that choice is
    /// persisted via the `SelectedLanguage` key directly and overrides this.
    /// Brazilian (and broadly Portuguese-speaking) users land on "pt" out of
    /// the box; everyone else gets "en" to preserve previous behavior.
    private static var defaultSelectedLanguage: String {
        let code = Locale.current.language.languageCode?.identifier
            ?? Locale.current.identifier.split(separator: "_").first.map(String.init)
            ?? "en"
        return code.lowercased() == "pt" ? "pt" : "en"
    }

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            // Onboarding & General
            "hasCompletedOnboarding": false,
            "enableAnnouncements": true,
            // This fork (pinhosystems/VoiceInk) does not auto-update from the
            // upstream Beingpax appcast — see Info.plist SUFeedURL comment.
            // Default OFF prevents Sparkle from probing on first launch.
            "autoUpdateCheck": false,

            // Clipboard
            "restoreClipboardAfterPaste": true,
            "clipboardRestoreDelay": 2.0,
            "useAppleScriptPaste": false,

            // Audio & Media
            "isSystemMuteEnabled": true,
            "audioResumptionDelay": 0.0,
            "isPauseMediaEnabled": false,
            "isSoundFeedbackEnabled": true,

            // Recording & Transcription
            "IsTextFormattingEnabled": true,
            "IsVADEnabled": true,
            "RemoveFillerWords": true,
            "RemovePunctuation": false,
            "LowercaseTranscription": false,
            "SelectedLanguage": defaultSelectedLanguage,
            // Global default app language. Drives the initial value of every
            // per-context language picker (STT model language, LLM output
            // language, Power Mode language, ...) on first launch and after
            // the user explicitly picks one in Settings. Each picker still
            // owns its own UserDefault — the default-app-language acts as the
            // seed + propagation source, not a runtime override.
            "DefaultAppLanguage": defaultSelectedLanguage,
            // True once the user has confirmed the default language through
            // the onboarding step (or by explicitly re-picking it in
            // Settings). A fresh install starts at false so the onboarding
            // gate fires before the welcome greeting. Set explicitly to true
            // by upgrade paths in `runInitialFlagsIfNeeded` to avoid
            // re-prompting existing users.
            "DefaultAppLanguageConfirmed": false,
            "AppendTrailingSpace": true,
            "showLiveTextPreview": false,
            "RecorderType": "mini",

            // Cleanup
            "IsTranscriptionCleanupEnabled": false,
            "TranscriptionRetentionMinutes": 1440,
            "IsAudioCleanupEnabled": false,
            "AudioRetentionPeriod": 7,
            // Troubleshooting-log retention. 0 disables the sweep entirely;
            // any positive integer is interpreted as days.
            "TroubleshootingLogRetentionDays": 7,

            // UI & Behavior
            "IsMenuBarOnly": false,
            // Power Mode is now a permanent, always-on feature. The flag
            // stays in the registered defaults purely so legacy paths that
            // still read it (logs, exported diagnostics) see `true`. The UI
            // no longer exposes a way to disable it.
            "powerModeUIFlag": true,
            "powerModePersistConfig": false,
            // Hotkey
            "isMiddleClickToggleEnabled": false,
            "middleClickActivationDelay": 200,

            // Enhancement
            "SkipShortEnhancement": true,
            "ShortEnhancementWordThreshold": 3,
            "EnhancementTimeoutSeconds": 7,
            "EnhancementRetryOnTimeout": true,

            // Locale-aware post-processing. Default ON: the normalizer only
            // applies the active LocalePack's rules (currently BR-only via
            // BrazilianPortuguesePack.customNormalize), so it is inert for
            // every locale without curated input transforms — no downside to
            // shipping enabled.
            "LocaleNormalizationEnabled": true,

            // LLM output language. `match` keeps the legacy behavior — the
            // LLM enhancement responds in the same language the audio was
            // transcribed in. Any BCP-47 value here decouples the output
            // language from the STT language and turns enhancement into a
            // translate-and-clean step (e.g. dictate in pt-BR, get an
            // English email out).
            "LLMOutputLanguage": "match",

            // Model
            "PrewarmModelOnWake": true,

        ])

        migrateLegacyNormalizationKeyIfNeeded()
        PunctuationCleanupMode.migrateLegacyUserDefaultIfNeeded()
        markDefaultAppLanguageConfirmedForExistingInstalls()
        forcePowerModeAlwaysOn()
    }

    /// Power Mode is no longer toggleable; flip the legacy flag so every
    /// runtime read returns true regardless of what the user had before.
    /// Idempotent — once true, the call is a no-op.
    private static func forcePowerModeAlwaysOn() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: "powerModeUIFlag") else { return }
        defaults.set(true, forKey: "powerModeUIFlag")
    }

    /// Users who completed onboarding before the language-confirm gate
    /// existed already chose a language implicitly (we registered
    /// SelectedLanguage from locale). Flag DefaultAppLanguageConfirmed true
    /// on first launch of the new build so the gate does not re-prompt
    /// them. Idempotent: only runs when the flag is at its registered
    /// default state (false) AND onboarding was already completed.
    private static func markDefaultAppLanguageConfirmedForExistingInstalls() {
        let defaults = UserDefaults.standard
        let confirmedKey = "DefaultAppLanguageConfirmed"
        // Only fires when the user truly never explicitly set the flag —
        // checking `object(forKey:)` would be false-positive after a fresh
        // install with the registered default applied. The registered
        // default is `false`, so distinguishing "never set" from
        // "registered default" requires the onboarding side-flag.
        guard defaults.bool(forKey: "hasCompletedOnboarding"),
              !defaults.bool(forKey: confirmedKey) else { return }
        defaults.set(true, forKey: confirmedKey)
    }

    /// One-shot migration: if the legacy `BrazilianNormalizationEnabled` key
    /// has an explicit user-set value (i.e. the user toggled it off in an
    /// earlier build) and the new `LocaleNormalizationEnabled` key has not yet
    /// been written, copy the legacy value across and remove the legacy entry.
    /// Idempotent — subsequent launches find the new key already set and skip.
    private static func migrateLegacyNormalizationKeyIfNeeded() {
        let defaults = UserDefaults.standard
        let newKey = LocalePackRegistry.normalizationEnabledKey
        let legacyKey = LocalePackRegistry.legacyNormalizationEnabledKey

        guard defaults.object(forKey: newKey) == nil else { return }
        guard let legacyValue = defaults.object(forKey: legacyKey) else { return }
        if let bool = legacyValue as? Bool {
            defaults.set(bool, forKey: newKey)
        }
        defaults.removeObject(forKey: legacyKey)
    }
}

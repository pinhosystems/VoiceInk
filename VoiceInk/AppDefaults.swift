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

            // Model
            "PrewarmModelOnWake": true,

        ])

        migrateLegacyNormalizationKeyIfNeeded()
        PunctuationCleanupMode.migrateLegacyUserDefaultIfNeeded()
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

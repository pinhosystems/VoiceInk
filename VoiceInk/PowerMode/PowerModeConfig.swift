import Foundation
import KeyboardShortcuts

enum AutoSendKey: String, Codable, CaseIterable {
    case none = "none"
    case enter = "enter"
    case shiftEnter = "shiftEnter"
    case commandEnter = "commandEnter"

    var displayName: String {
        switch self {
        case .none: return "None"
        case .enter: return "Return (⏎)"
        case .shiftEnter: return "Shift + Return (⇧⏎)"
        case .commandEnter: return "Command + Return (⌘⏎)"
        }
    }

    var isEnabled: Bool {
        self != .none
    }
}

struct PowerModeConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var emoji: String
    var appConfigs: [AppConfig]?
    var urlConfigs: [URLConfig]?
    var isAIEnhancementEnabled: Bool
    var selectedPrompt: String?
    var selectedTranscriptionModelName: String?
    var selectedLanguage: String?
    var isTextFormattingEnabled: Bool = false
    var punctuationCleanupMode: PunctuationCleanupMode = .keep
    var lowercaseTranscription: Bool = false
    var useScreenCapture: Bool
    var selectedAIProvider: String?
    var selectedAIModel: String?
    var autoSendKey: AutoSendKey = .none
    var isEnabled: Bool = true
    var isDefault: Bool = false
    var hotkeyShortcut: String? = nil

    // Optional overrides — when nil, the Power Mode does not touch the
    // corresponding system default; when set, the value is applied while
    // the session is active and reverted on session end. Lets a profile
    // declare "default" for any field by simply leaving the override unset.
    var llmOutputLanguageOverride: String? = nil
    var localeNormalizationEnabledOverride: Bool? = nil
    var whisperPromptDomainOverride: String? = nil
    var removeFillerWordsOverride: Bool? = nil
    var appendTrailingSpaceOverride: Bool? = nil

    // Section-level customization flags. When false, the entire transcription
    // (resp. LLM) section is treated as "use system defaults" — the Power Mode
    // session leaves the corresponding UserDefaults / service state untouched
    // when it activates. Defaults to true to preserve legacy behavior for any
    // config saved before this field existed.
    var customizeTranscription: Bool = true
    var customizeLLM: Bool = true

    enum CodingKeys: String, CodingKey {
        // `removePunctuation` is kept as a legacy key so older exports decode
        // cleanly — the init(from:) below tries `punctuationCleanupMode` first
        // and falls back to the legacy bool. `hotkeyShortcut` was added by this
        // fork before the upstream cleanup landed; we keep it to preserve PR #X
        // configs that round-trip per-config keyboard shortcuts.
        case id, name, emoji, appConfigs, urlConfigs, isAIEnhancementEnabled, selectedPrompt, selectedLanguage, isTextFormattingEnabled, punctuationCleanupMode, removePunctuation, lowercaseTranscription, useScreenCapture, selectedAIProvider, selectedAIModel, isAutoSendEnabled, autoSendKey, isEnabled, isDefault, hotkeyShortcut
        case selectedWhisperModel
        case selectedTranscriptionModelName
        case llmOutputLanguageOverride, localeNormalizationEnabledOverride, whisperPromptDomainOverride, removeFillerWordsOverride, appendTrailingSpaceOverride
        case customizeTranscription, customizeLLM
    }

    init(id: UUID = UUID(), name: String, emoji: String, appConfigs: [AppConfig]? = nil,
         urlConfigs: [URLConfig]? = nil, isAIEnhancementEnabled: Bool, selectedPrompt: String? = nil,
         selectedTranscriptionModelName: String? = nil, selectedLanguage: String? = nil, useScreenCapture: Bool = false,
         isTextFormattingEnabled: Bool = false, punctuationCleanupMode: PunctuationCleanupMode = .keep, lowercaseTranscription: Bool = false,
         selectedAIProvider: String? = nil, selectedAIModel: String? = nil, autoSendKey: AutoSendKey = .none, isEnabled: Bool = true, isDefault: Bool = false, hotkeyShortcut: String? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.appConfigs = appConfigs
        self.urlConfigs = urlConfigs
        self.isAIEnhancementEnabled = isAIEnhancementEnabled
        self.selectedPrompt = selectedPrompt
        self.useScreenCapture = useScreenCapture
        self.autoSendKey = autoSendKey
        self.selectedAIProvider = selectedAIProvider ?? UserDefaults.standard.string(forKey: "selectedAIProvider")
        self.selectedAIModel = selectedAIModel
        self.selectedTranscriptionModelName = selectedTranscriptionModelName ?? UserDefaults.standard.string(forKey: "CurrentTranscriptionModel")
        // Preserve the nil sentinel — it represents "inherit from global
        // Default App Language" and PowerModeSessionManager.applyConfiguration
        // skips the language write when this is nil. Auto-filling from
        // UserDefaults here would silently bake the *current* global value
        // into the saved profile, breaking the inherit semantics on every
        // subsequent global-language change.
        self.selectedLanguage = selectedLanguage
        self.isTextFormattingEnabled = isTextFormattingEnabled
        self.punctuationCleanupMode = punctuationCleanupMode
        self.lowercaseTranscription = lowercaseTranscription
        self.isEnabled = isEnabled
        self.isDefault = isDefault
        self.hotkeyShortcut = hotkeyShortcut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        emoji = try container.decode(String.self, forKey: .emoji)
        appConfigs = try container.decodeIfPresent([AppConfig].self, forKey: .appConfigs)
        urlConfigs = try container.decodeIfPresent([URLConfig].self, forKey: .urlConfigs)
        isAIEnhancementEnabled = try container.decode(Bool.self, forKey: .isAIEnhancementEnabled)
        selectedPrompt = try container.decodeIfPresent(String.self, forKey: .selectedPrompt)
        selectedLanguage = try container.decodeIfPresent(String.self, forKey: .selectedLanguage)
        isTextFormattingEnabled = try container.decodeIfPresent(Bool.self, forKey: .isTextFormattingEnabled) ?? false
        if let mode = try container.decodeIfPresent(PunctuationCleanupMode.self, forKey: .punctuationCleanupMode) {
            punctuationCleanupMode = mode
        } else {
            let removePunctuation = try container.decodeIfPresent(Bool.self, forKey: .removePunctuation) ?? false
            punctuationCleanupMode = removePunctuation ? .removeAll : .keep
        }
        lowercaseTranscription = try container.decodeIfPresent(Bool.self, forKey: .lowercaseTranscription) ?? false
        useScreenCapture = try container.decode(Bool.self, forKey: .useScreenCapture)
        selectedAIProvider = try container.decodeIfPresent(String.self, forKey: .selectedAIProvider)
        selectedAIModel = try container.decodeIfPresent(String.self, forKey: .selectedAIModel)
        // Migrate from old isAutoSendEnabled bool to new autoSendKey enum
        if let rawValue = try container.decodeIfPresent(String.self, forKey: .autoSendKey),
           let newKey = AutoSendKey(rawValue: rawValue) {
            autoSendKey = newKey
        } else if let oldBool = try container.decodeIfPresent(Bool.self, forKey: .isAutoSendEnabled), oldBool {
            autoSendKey = .enter
        } else {
            autoSendKey = .none
        }
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        hotkeyShortcut = try container.decodeIfPresent(String.self, forKey: .hotkeyShortcut)
        llmOutputLanguageOverride = try container.decodeIfPresent(String.self, forKey: .llmOutputLanguageOverride)
        localeNormalizationEnabledOverride = try container.decodeIfPresent(Bool.self, forKey: .localeNormalizationEnabledOverride)
        whisperPromptDomainOverride = try container.decodeIfPresent(String.self, forKey: .whisperPromptDomainOverride)
        removeFillerWordsOverride = try container.decodeIfPresent(Bool.self, forKey: .removeFillerWordsOverride)
        appendTrailingSpaceOverride = try container.decodeIfPresent(Bool.self, forKey: .appendTrailingSpaceOverride)
        customizeTranscription = try container.decodeIfPresent(Bool.self, forKey: .customizeTranscription) ?? true
        customizeLLM = try container.decodeIfPresent(Bool.self, forKey: .customizeLLM) ?? true

        if let newModelName = try container.decodeIfPresent(String.self, forKey: .selectedTranscriptionModelName) {
            selectedTranscriptionModelName = newModelName
        } else if let oldModelName = try container.decodeIfPresent(String.self, forKey: .selectedWhisperModel) {
            selectedTranscriptionModelName = oldModelName
        } else {
            selectedTranscriptionModelName = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(emoji, forKey: .emoji)
        try container.encodeIfPresent(appConfigs, forKey: .appConfigs)
        try container.encodeIfPresent(urlConfigs, forKey: .urlConfigs)
        try container.encode(isAIEnhancementEnabled, forKey: .isAIEnhancementEnabled)
        try container.encodeIfPresent(selectedPrompt, forKey: .selectedPrompt)
        try container.encodeIfPresent(selectedLanguage, forKey: .selectedLanguage)
        try container.encode(isTextFormattingEnabled, forKey: .isTextFormattingEnabled)
        try container.encode(punctuationCleanupMode, forKey: .punctuationCleanupMode)
        try container.encode(punctuationCleanupMode == .removeAll, forKey: .removePunctuation)
        try container.encode(lowercaseTranscription, forKey: .lowercaseTranscription)
        try container.encode(useScreenCapture, forKey: .useScreenCapture)
        try container.encodeIfPresent(selectedAIProvider, forKey: .selectedAIProvider)
        try container.encodeIfPresent(selectedAIModel, forKey: .selectedAIModel)
        try container.encode(autoSendKey, forKey: .autoSendKey)
        try container.encodeIfPresent(selectedTranscriptionModelName, forKey: .selectedTranscriptionModelName)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encodeIfPresent(hotkeyShortcut, forKey: .hotkeyShortcut)
        try container.encodeIfPresent(llmOutputLanguageOverride, forKey: .llmOutputLanguageOverride)
        try container.encodeIfPresent(localeNormalizationEnabledOverride, forKey: .localeNormalizationEnabledOverride)
        try container.encodeIfPresent(whisperPromptDomainOverride, forKey: .whisperPromptDomainOverride)
        try container.encodeIfPresent(removeFillerWordsOverride, forKey: .removeFillerWordsOverride)
        try container.encodeIfPresent(appendTrailingSpaceOverride, forKey: .appendTrailingSpaceOverride)
        try container.encode(customizeTranscription, forKey: .customizeTranscription)
        try container.encode(customizeLLM, forKey: .customizeLLM)
    }
    
    
    static func == (lhs: PowerModeConfig, rhs: PowerModeConfig) -> Bool {
        lhs.id == rhs.id
    }
}

struct AppConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var bundleIdentifier: String
    var appName: String
    
    init(id: UUID = UUID(), bundleIdentifier: String, appName: String) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
    }
    
    static func == (lhs: AppConfig, rhs: AppConfig) -> Bool {
        lhs.id == rhs.id
    }
}

struct URLConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var url: String
    
    init(id: UUID = UUID(), url: String) {
        self.id = id
        self.url = url
    }
    
    static func == (lhs: URLConfig, rhs: URLConfig) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
class PowerModeManager: ObservableObject {
    static let shared = PowerModeManager()
    @Published var configurations: [PowerModeConfig] = []
    @Published var activeConfiguration: PowerModeConfig?

    private let configKey = "powerModeConfigurationsV2"
    private let activeConfigIdKey = "activeConfigurationId"

    private init() {
        loadConfigurations()

        if let activeConfigIdString = UserDefaults.standard.string(forKey: activeConfigIdKey),
           let activeConfigId = UUID(uuidString: activeConfigIdString) {
            activeConfiguration = configurations.first { $0.id == activeConfigId }
        } else {
            activeConfiguration = nil
        }
    }

    private func loadConfigurations() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let configs = try? JSONDecoder().decode([PowerModeConfig].self, from: data) {
            configurations = configs
        }
    }

    func saveConfigurations() {
        if let data = try? JSONEncoder().encode(configurations) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
        NotificationCenter.default.post(name: NSNotification.Name("PowerModeConfigurationsDidChange"), object: nil)
    }

    func addConfiguration(_ config: PowerModeConfig) {
        if !configurations.contains(where: { $0.id == config.id }) {
            configurations.append(config)
            saveConfigurations()
        }
    }

    func removeConfiguration(with id: UUID) {
        KeyboardShortcuts.setShortcut(nil, for: .powerMode(id: id))
        configurations.removeAll { $0.id == id }
        saveConfigurations()
    }

    func getConfiguration(with id: UUID) -> PowerModeConfig? {
        return configurations.first { $0.id == id }
    }

    func updateConfiguration(_ config: PowerModeConfig) {
        if let index = configurations.firstIndex(where: { $0.id == config.id }) {
            configurations[index] = config
            saveConfigurations()
        }
    }

    func moveConfigurations(fromOffsets: IndexSet, toOffset: Int) {
        configurations.move(fromOffsets: fromOffsets, toOffset: toOffset)
        saveConfigurations()
    }

    /// Clones `source` into a new configuration inserted immediately after it
    /// in the priority list, so the duplicate inherits the next-lower
    /// priority slot. The copy never inherits `isDefault` (only one default
    /// allowed) or `hotkeyShortcut` (per-config shortcuts must stay unique)
    /// and is created disabled to avoid silently shadowing the source on
    /// the next app match.
    @discardableResult
    func duplicateConfiguration(_ source: PowerModeConfig) -> PowerModeConfig? {
        guard let sourceIndex = configurations.firstIndex(where: { $0.id == source.id }) else {
            return nil
        }
        var copy = source
        copy.id = UUID()
        copy.name = uniqueName(basedOn: source.name)
        copy.isDefault = false
        copy.hotkeyShortcut = nil
        copy.isEnabled = false

        configurations.insert(copy, at: sourceIndex + 1)
        saveConfigurations()
        return copy
    }

    /// Produces a duplicate-safe name. First tries "<name> (Copy)"; if that
    /// already exists, appends " 2", " 3", … until it finds a free slot.
    private func uniqueName(basedOn original: String) -> String {
        let base = "\(original) (Copy)"
        if !configurations.contains(where: { $0.name == base }) {
            return base
        }
        var index = 2
        while configurations.contains(where: { $0.name == "\(base) \(index)" }) {
            index += 1
        }
        return "\(base) \(index)"
    }

    func getConfigurationForURL(_ url: String) -> PowerModeConfig? {
        for config in configurations.filter({ $0.isEnabled }) {
            if let urlConfigs = config.urlConfigs {
                for urlConfig in urlConfigs where Self.urlMatches(actual: url, configured: urlConfig.url) {
                    return config
                }
            }
        }
        return nil
    }

    /// True when a Power Mode URL trigger should fire for the actively
    /// visited URL. The previous implementation compared `cleanURL`-normalized
    /// strings with `String.contains`, which incorrectly matched any URL whose
    /// cleaned form contained the trigger as a substring — e.g. a trigger of
    /// `"amazon.com"` would fire on `"amazon.com.br"`, on `"amazon.com.fake.io"`,
    /// or on a totally unrelated URL with `amazon.com` in the path.
    ///
    /// Now compares hosts with component-boundary suffix matching:
    /// `"amazon.com"` matches `"amazon.com"`, `"www.amazon.com"` and
    /// `"shop.amazon.com"` but not `"amazon.com.br"`. Falls back to substring
    /// on cleaned strings when one side does not parse as a URL (covers
    /// path-only or otherwise non-URL trigger strings the user may have
    /// configured in earlier versions).
    static func urlMatches(actual: String, configured: String) -> Bool {
        if let actualHost = canonicalHost(from: actual),
           let configHost = canonicalHost(from: configured) {
            return actualHost == configHost || actualHost.hasSuffix("." + configHost)
        }
        let cleanedActual = staticCleanURL(actual)
        let cleanedConfigured = staticCleanURL(configured)
        return cleanedActual.contains(cleanedConfigured)
    }

    private static func canonicalHost(from rawURL: String) -> String? {
        let trimmed = rawURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        // URLComponents needs a scheme to recognize the host. Add a default
        // one when missing so plain triggers like "github.com" parse correctly.
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let components = URLComponents(string: withScheme),
              var host = components.host?.lowercased(),
              !host.isEmpty else {
            return nil
        }
        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        return host
    }

    private static func staticCleanURL(_ url: String) -> String {
        url.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func getConfigurationForApp(_ bundleId: String) -> PowerModeConfig? {
        for config in configurations.filter({ $0.isEnabled }) {
            if let appConfigs = config.appConfigs {
                if appConfigs.contains(where: { $0.bundleIdentifier == bundleId }) {
                    return config
                }
            }
        }
        return nil
    }
    
    func getDefaultConfiguration() -> PowerModeConfig? {
        return configurations.first { $0.isEnabled && $0.isDefault }
    }
    
    func hasDefaultConfiguration() -> Bool {
        return configurations.contains { $0.isDefault }
    }
    
    func setAsDefault(configId: UUID, skipSave: Bool = false) {
        for index in configurations.indices {
            configurations[index].isDefault = false
        }

        if let index = configurations.firstIndex(where: { $0.id == configId }) {
            configurations[index].isDefault = true
        }

        if !skipSave {
            saveConfigurations()
        }
    }
    
    func enableConfiguration(with id: UUID) {
        if let index = configurations.firstIndex(where: { $0.id == id }) {
            configurations[index].isEnabled = true
            saveConfigurations()
        }
    }
    
    func disableConfiguration(with id: UUID) {
        if let index = configurations.firstIndex(where: { $0.id == id }) {
            configurations[index].isEnabled = false
            saveConfigurations()
        }
    }
    
    var enabledConfigurations: [PowerModeConfig] {
        return configurations.filter { $0.isEnabled }
    }

    func addAppConfig(_ appConfig: AppConfig, to config: PowerModeConfig) {
        if var updatedConfig = configurations.first(where: { $0.id == config.id }) {
            var configs = updatedConfig.appConfigs ?? []
            configs.append(appConfig)
            updatedConfig.appConfigs = configs
            updateConfiguration(updatedConfig)
        }
    }

    func removeAppConfig(_ appConfig: AppConfig, from config: PowerModeConfig) {
        if var updatedConfig = configurations.first(where: { $0.id == config.id }) {
            updatedConfig.appConfigs?.removeAll(where: { $0.id == appConfig.id })
            updateConfiguration(updatedConfig)
        }
    }

    func addURLConfig(_ urlConfig: URLConfig, to config: PowerModeConfig) {
        if var updatedConfig = configurations.first(where: { $0.id == config.id }) {
            var configs = updatedConfig.urlConfigs ?? []
            configs.append(urlConfig)
            updatedConfig.urlConfigs = configs
            updateConfiguration(updatedConfig)
        }
    }

    func removeURLConfig(_ urlConfig: URLConfig, from config: PowerModeConfig) {
        if var updatedConfig = configurations.first(where: { $0.id == config.id }) {
            updatedConfig.urlConfigs?.removeAll(where: { $0.id == urlConfig.id })
            updateConfiguration(updatedConfig)
        }
    }

    func cleanURL(_ url: String) -> String {
        return url.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func setActiveConfiguration(_ config: PowerModeConfig?) {
        activeConfiguration = config
        UserDefaults.standard.set(config?.id.uuidString, forKey: activeConfigIdKey)
        self.objectWillChange.send()
    }

    var currentActiveConfiguration: PowerModeConfig? {
        return activeConfiguration
    }

    func getAllAvailableConfigurations() -> [PowerModeConfig] {
        return configurations
    }

    func isEmojiInUse(_ emoji: String) -> Bool {
        return configurations.contains { $0.emoji == emoji }
    }
} 

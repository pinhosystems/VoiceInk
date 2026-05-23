import Foundation
import AppKit

/// A ready-made Power Mode template the user can pick from instead of
/// building a configuration from scratch. Presets capture the *intent*
/// (e.g. "I'm dictating into a chat app, autosend on, use the Chat
/// prompt") rather than a specific configuration — the apply step
/// filters the suggested bundle IDs down to ones actually installed on
/// the user's machine, so the resulting `PowerModeConfig` has no dead
/// references.
///
/// Adding a preset:
/// 1. Append to `PowerModePresets.all`.
/// 2. Reference a prompt template by its stable
///    `PromptTemplates.TemplateID.*` UUID — never by title.
/// 3. Keep bundle IDs lowercased exactly as Apple ships them
///    (case-sensitive on `urlForApplication(withBundleIdentifier:)`).
struct PowerModePreset: Identifiable {
    enum Category: String, CaseIterable, Identifiable {
        case aiCodingAgent
        case devEnvironment
        case messaging
        case email
        case writing
        case aiChat

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .aiCodingAgent:  return "AI Coding Agent"
            case .devEnvironment: return "Dev Environment"
            case .messaging:      return "Messaging"
            case .email:          return "Email"
            case .writing:        return "Writing"
            case .aiChat:         return "AI Chat"
            }
        }
    }

    struct SuggestedApp {
        let bundleID: String
        let displayName: String
    }

    let id: UUID
    let category: Category
    let emoji: String
    let name: String
    let description: String
    let suggestedApps: [SuggestedApp]
    let suggestedURLs: [String]
    /// Stable ID of a prompt template in `PromptTemplates.all`. The apply
    /// step clones the template into a `CustomPrompt` and stores the new
    /// prompt's UUID on the resulting `PowerModeConfig`.
    let promptTemplateID: UUID
    let isAIEnhancementEnabled: Bool
    let useScreenCapture: Bool
    let autoSendKey: AutoSendKey
    let isTextFormattingEnabled: Bool
    let punctuationCleanupMode: PunctuationCleanupMode
    let lowercaseTranscription: Bool
}

enum PowerModePresets {

    static let all: [PowerModePreset] = [

        // MARK: - AI Coding Agent
        //
        // Speech-to-prompt for users delegating work to Claude Code,
        // Cursor chat, or Copilot Chat. Screen capture is on so the LLM
        // can ground the brief in the visible editor state. Auto-send
        // stays off — the user typically reviews the assembled prompt
        // before submitting it.
        PowerModePreset(
            id: UUID(uuidString: "0F0E0002-0000-0000-0000-000000000001")!,
            category: .aiCodingAgent,
            emoji: "🤖",
            name: "AI Coding Agent",
            description: "Cursor chat, Claude Code, Copilot Chat. Cleans your speech into a structured task brief — does not write code.",
            suggestedApps: [
                .init(bundleID: "com.todesktop.230313mzl4w4u92", displayName: "Cursor"),
            ],
            suggestedURLs: [
                // Anchor on the /code path so this preset wins over the
                // generic AI Chat preset on claude.ai. Order matters in
                // PowerModeManager — keep this preset above AI Chat in
                // the user's configurations list.
                "claude.ai/code",
            ],
            promptTemplateID: PromptTemplates.TemplateID.taskPrompt,
            isAIEnhancementEnabled: true,
            useScreenCapture: true,
            autoSendKey: .none,
            isTextFormattingEnabled: false,
            punctuationCleanupMode: .keep,
            lowercaseTranscription: false
        ),

        // MARK: - Dev Environment
        //
        // Catch-all for IDEs and terminals. Output goes into source
        // files or the shell — a short cleaned line is the right shape.
        // Screen capture stays off because the editor already carries
        // the relevant code, and capturing every Cmd-K dictation would
        // be noisy. Auto-send stays off — the user controls submission.
        PowerModePreset(
            id: UUID(uuidString: "0F0E0002-0000-0000-0000-000000000002")!,
            category: .devEnvironment,
            emoji: "💻",
            name: "Dev Environment",
            description: "IDEs and terminals — Xcode, VS Code, JetBrains, Zed, Terminal, iTerm, Warp, and friends.",
            suggestedApps: [
                .init(bundleID: "com.apple.dt.Xcode",                displayName: "Xcode"),
                .init(bundleID: "com.microsoft.VSCode",              displayName: "Visual Studio Code"),
                .init(bundleID: "dev.zed.Zed",                       displayName: "Zed"),
                .init(bundleID: "com.jetbrains.intellij",            displayName: "IntelliJ IDEA"),
                .init(bundleID: "com.jetbrains.intellij.ce",         displayName: "IntelliJ IDEA CE"),
                .init(bundleID: "com.jetbrains.pycharm",             displayName: "PyCharm"),
                .init(bundleID: "com.jetbrains.WebStorm",            displayName: "WebStorm"),
                .init(bundleID: "com.jetbrains.goland",              displayName: "GoLand"),
                .init(bundleID: "com.google.android.studio",         displayName: "Android Studio"),
                .init(bundleID: "com.sublimetext.4",                 displayName: "Sublime Text"),
                .init(bundleID: "com.panic.Nova",                    displayName: "Nova"),
                .init(bundleID: "com.apple.Terminal",                displayName: "Terminal"),
                .init(bundleID: "com.googlecode.iterm2",             displayName: "iTerm"),
                .init(bundleID: "dev.warp.Warp-Stable",              displayName: "Warp"),
                .init(bundleID: "com.mitchellh.ghostty",             displayName: "Ghostty"),
                .init(bundleID: "io.alacritty",                      displayName: "Alacritty"),
            ],
            suggestedURLs: [],
            promptTemplateID: PromptTemplates.TemplateID.codeComment,
            isAIEnhancementEnabled: true,
            useScreenCapture: false,
            autoSendKey: .none,
            isTextFormattingEnabled: false,
            punctuationCleanupMode: .keep,
            lowercaseTranscription: false
        ),

        // MARK: - Messaging
        //
        // Generic chat surface: native messaging apps + the web
        // counterparts of the big team-chat platforms. Auto-send fires
        // ⏎ because chat messages are typically sent immediately and
        // re-typing the send key by voice is awkward.
        PowerModePreset(
            id: UUID(uuidString: "0F0E0002-0000-0000-0000-000000000003")!,
            category: .messaging,
            emoji: "💬",
            name: "Messaging",
            description: "Slack, Teams, Discord, iMessage, WhatsApp, Telegram, Google Chat — chat tone + auto-send.",
            suggestedApps: [
                .init(bundleID: "com.tinyspeck.slackmacgap",        displayName: "Slack"),
                .init(bundleID: "com.microsoft.teams2",             displayName: "Microsoft Teams"),
                .init(bundleID: "com.microsoft.teams",              displayName: "Microsoft Teams (classic)"),
                .init(bundleID: "com.hnc.Discord",                  displayName: "Discord"),
                .init(bundleID: "com.apple.MobileSMS",              displayName: "Messages"),
                // Mac WhatsApp ships under `net.whatsapp.WhatsApp`. The
                // earlier `"WhatsApp"` placeholder never resolved via
                // NSWorkspace and silently dropped out of the preset.
                .init(bundleID: "net.whatsapp.WhatsApp",            displayName: "WhatsApp"),
                .init(bundleID: "desktop.WhatsApp",                 displayName: "WhatsApp (legacy)"),
                .init(bundleID: "ru.keepcoder.Telegram",            displayName: "Telegram"),
            ],
            suggestedURLs: [
                "chat.google.com",
                "web.whatsapp.com",
                "teams.microsoft.com",
                "discord.com/channels",
            ],
            promptTemplateID: PromptTemplates.TemplateID.chat,
            isAIEnhancementEnabled: true,
            useScreenCapture: false,
            autoSendKey: .enter,
            isTextFormattingEnabled: false,
            punctuationCleanupMode: .keep,
            lowercaseTranscription: false
        ),

        // MARK: - Email
        //
        // No auto-send — emails get reviewed before going out.
        PowerModePreset(
            id: UUID(uuidString: "0F0E0002-0000-0000-0000-000000000004")!,
            category: .email,
            emoji: "📨",
            name: "Email",
            description: "Mail, Superhuman, Spark, Gmail and Outlook on the web.",
            suggestedApps: [
                .init(bundleID: "com.apple.mail",         displayName: "Mail"),
                .init(bundleID: "com.superhuman.electron", displayName: "Superhuman"),
                .init(bundleID: "com.readdle.smartemail-Mac", displayName: "Spark"),
            ],
            suggestedURLs: [
                "mail.google.com",
                "outlook.live.com",
                "outlook.office.com",
            ],
            promptTemplateID: PromptTemplates.TemplateID.email,
            isAIEnhancementEnabled: true,
            useScreenCapture: false,
            autoSendKey: .none,
            isTextFormattingEnabled: false,
            punctuationCleanupMode: .keep,
            lowercaseTranscription: false
        ),

        // MARK: - Writing
        //
        // Long-form: notes, docs, knowledge bases. Rewrite for clarity,
        // keep paragraph breaks, no auto-send.
        PowerModePreset(
            id: UUID(uuidString: "0F0E0002-0000-0000-0000-000000000005")!,
            category: .writing,
            emoji: "📝",
            name: "Writing",
            description: "Notion, Bear, Obsidian, Ulysses, Pages, Google Docs.",
            suggestedApps: [
                .init(bundleID: "notion.id",                            displayName: "Notion"),
                .init(bundleID: "net.shinyfrog.bear",                   displayName: "Bear"),
                .init(bundleID: "md.obsidian",                          displayName: "Obsidian"),
                .init(bundleID: "com.ulyssesapp.mac",                   displayName: "Ulysses"),
                .init(bundleID: "com.apple.iWork.Pages",                displayName: "Pages"),
                .init(bundleID: "com.lukilabs.lukiapp",                 displayName: "Craft"),
            ],
            suggestedURLs: [
                "docs.google.com",
            ],
            promptTemplateID: PromptTemplates.TemplateID.rewrite,
            isAIEnhancementEnabled: true,
            useScreenCapture: false,
            autoSendKey: .none,
            isTextFormattingEnabled: true,
            punctuationCleanupMode: .keep,
            lowercaseTranscription: false
        ),

        // MARK: - AI Chat
        //
        // Web-based assistants. Screen capture on so the model can see
        // what the user is referencing on the page. Auto-send fires ⏎
        // since most AI chat surfaces accept Enter as submit.
        //
        // Important: this preset's `claude.ai` URL trigger overlaps
        // with the AI Coding Agent's `claude.ai/code` trigger. The user
        // should keep AI Coding Agent above AI Chat in the Reorder
        // panel so the more specific path wins.
        PowerModePreset(
            id: UUID(uuidString: "0F0E0002-0000-0000-0000-000000000006")!,
            category: .aiChat,
            emoji: "🧠",
            name: "AI Chat",
            description: "ChatGPT, Claude.ai, Gemini, Perplexity, Microsoft Copilot — web assistants.",
            suggestedApps: [],
            suggestedURLs: [
                "chatgpt.com",
                "chat.openai.com",
                "claude.ai",
                "gemini.google.com",
                "perplexity.ai",
                "copilot.microsoft.com",
            ],
            // AI Chat reuses the built-in Assistant predefined prompt
            // (no cloning needed). Using the Task Prompt template here
            // would produce a second "Task Prompt" entry in the picker
            // alongside the one cloned by the AI Coding Agent preset.
            promptTemplateID: PredefinedPrompts.assistantPromptId,
            isAIEnhancementEnabled: true,
            useScreenCapture: true,
            autoSendKey: .enter,
            isTextFormattingEnabled: false,
            punctuationCleanupMode: .keep,
            lowercaseTranscription: false
        ),
    ]

    static func presets(in category: PowerModePreset.Category) -> [PowerModePreset] {
        all.filter { $0.category == category }
    }
}

extension PowerModePreset {

    /// Filters `suggestedApps` down to ones actually installed on this
    /// machine. Apple uses bundle-identifier lookup for the modern API,
    /// which returns `nil` when the app isn't installed.
    func installedApps() -> [SuggestedApp] {
        suggestedApps.filter { app in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleID) != nil
        }
    }

    /// Materialize the preset into a fresh `PowerModeConfig` ready to
    /// hand to `ConfigurationView`. The caller is responsible for
    /// persisting both the cloned prompt (via AIEnhancementService) and
    /// the resulting config (via PowerModeManager).
    ///
    /// - Parameters:
    ///   - clonedPromptID: The UUID of the freshly cloned CustomPrompt
    ///     that the caller has already saved to AIEnhancementService.
    ///     Passing nil means the config will have no selected prompt
    ///     and the user has to pick one in the editor.
    ///   - filterInstalled: When true (default), `appConfigs` is
    ///     filtered to apps present on disk. Set false to populate the
    ///     editor with the full preset (e.g. for screenshots / docs).
    func toConfig(
        clonedPromptID: UUID?,
        filterInstalled: Bool = true
    ) -> PowerModeConfig {
        let apps = filterInstalled ? installedApps() : suggestedApps
        let appConfigs = apps.map { app in
            AppConfig(bundleIdentifier: app.bundleID, appName: app.displayName)
        }
        let urlConfigs = suggestedURLs.map { URLConfig(url: $0) }

        return PowerModeConfig(
            name: name,
            emoji: emoji,
            appConfigs: appConfigs.isEmpty ? nil : appConfigs,
            urlConfigs: urlConfigs.isEmpty ? nil : urlConfigs,
            isAIEnhancementEnabled: isAIEnhancementEnabled,
            selectedPrompt: clonedPromptID?.uuidString,
            useScreenCapture: useScreenCapture,
            isTextFormattingEnabled: isTextFormattingEnabled,
            punctuationCleanupMode: punctuationCleanupMode,
            lowercaseTranscription: lowercaseTranscription,
            autoSendKey: autoSendKey,
            isEnabled: true,
            isDefault: false
        )
    }
}

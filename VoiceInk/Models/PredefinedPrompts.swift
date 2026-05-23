import Foundation
import SwiftUI    // Import to ensure we have access to SwiftUI types if needed

enum PredefinedPrompts {
    private static let predefinedPromptsKey = "PredefinedPrompts"

    // Static UUIDs for predefined prompts
    static let defaultPromptId   = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let assistantPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    /// Speech-to-clean-task-brief for AI coding agents (Claude Code,
    /// Cursor chat, Copilot Chat). Promoted from a clonable template
    /// to a predefined prompt so the Power Mode \"AI Coding Agent\"
    /// preset can reference one shared instance instead of cloning a
    /// fresh \"Task Prompt\" copy every time the user applies the
    /// preset.
    static let taskPromptId      = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    static var all: [CustomPrompt] {
        // Always return the latest predefined prompts from source code
        createDefaultPrompts()
    }

    static func createDefaultPrompts() -> [CustomPrompt] {
        [
            CustomPrompt(
                id: defaultPromptId,
                title: "Default",
                promptText: PromptTemplates.all.first { $0.title == "System Default" }?.promptText ?? "",
                icon: "checkmark.seal.fill",
                description: "Default mode to improved clarity and accuracy of the transcription",
                isPredefined: true,
                useSystemInstructions: true
            ),

            CustomPrompt(
                id: assistantPromptId,
                title: "Assistant",
                // The runtime overrides this with the dynamic
                // AIPrompts.assistantMode(flags:) in AIEnhancementService —
                // this stored value is only a placeholder for surfaces that
                // display promptText raw (e.g. backup exports).
                promptText: AIPrompts.assistantMode(flags: .all),
                icon: "bubble.left.and.bubble.right.fill",
                description: "AI assistant that provides direct answers to queries",
                isPredefined: true,
                useSystemInstructions: false
            ),

            CustomPrompt(
                id: taskPromptId,
                title: "Task Prompt",
                promptText: """
                Convert <TRANSCRIPT> into a clear, structured task brief for an AI coding agent (Claude Code, Cursor, Copilot Chat).

                Rules:
                - Do NOT write code. Output a prompt the agent will then act on.
                - Drop fillers, restate-corrections, tangents.
                - Preserve file paths, function names, library names, commands EXACTLY as spoken.
                - Preserve numeric constraints (timeouts, limits, versions).
                - When the user enumerates steps or requirements, format as a bullet list.
                - When the user gives context AND a goal, separate them: brief context paragraph, then "Task:" line, then constraints.
                - Imperative voice. Specific. No hedging.

                Output only the cleaned brief — no preamble, no closing.
                """,
                icon: "brain.head.profile",
                description: "Clean task brief for Claude Code, Cursor, Copilot Chat",
                isPredefined: true,
                useSystemInstructions: false,
                category: .dev_ai
            ),
        ]
    }
}

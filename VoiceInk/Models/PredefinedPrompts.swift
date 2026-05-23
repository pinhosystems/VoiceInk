import Foundation
import SwiftUI    // Import to ensure we have access to SwiftUI types if needed

enum PredefinedPrompts {
    private static let predefinedPromptsKey = "PredefinedPrompts"

    // Static UUIDs for predefined prompts. Stable across releases —
    // rotating one orphans every user-saved selection pointing at it.
    static let defaultPromptId     = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    static let assistantPromptId   = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    static let taskPromptId        = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    static let rewritePromptId     = UUID(uuidString: "00000000-0000-0000-0000-000000000004")!
    static let emailPromptId       = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    static let chatPromptId        = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
    static let codeCommentPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000007")!

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

            CustomPrompt(
                id: rewritePromptId,
                title: "Rewrite",
                promptText: "Rewrite <TRANSCRIPT> with better clarity and flow. Preserve meaning, tone, and facts. Output only the rewritten text.",
                icon: "pencil.circle.fill",
                description: "Rewrite with better clarity",
                isPredefined: true,
                useSystemInstructions: false,
                category: .writing
            ),

            CustomPrompt(
                id: emailPromptId,
                title: "Email",
                promptText: "Rewrite <TRANSCRIPT> as an email: greeting, 2–4 sentence body, closing. Match the <TRANSCRIPT> language. Friendly tone unless clearly professional. Keep all facts, names, dates, action items.",
                icon: "envelope.fill",
                description: "Professional email formatting",
                isPredefined: true,
                useSystemInstructions: false,
                category: .writing
            ),

            CustomPrompt(
                id: chatPromptId,
                title: "Chat",
                promptText: "Rewrite <TRANSCRIPT> as a short informal chat message. Keep emojis. No greetings or sign-offs.",
                icon: "bubble.left.and.bubble.right.fill",
                description: "Casual chat-style formatting",
                isPredefined: true,
                useSystemInstructions: false,
                category: .chat
            ),

            CustomPrompt(
                id: codeCommentPromptId,
                title: "Code Comment",
                promptText: """
                Rewrite <TRANSCRIPT> as an inline code comment.

                Rules:
                - One or two lines. Concise. No prose padding.
                - Explain *why*, not what the code obviously does.
                - Imperative or declarative tone, not first-person.
                - No leading `//` or `#` — the editor adds those.
                - Preserve identifiers, file paths, and numeric values exactly.

                Output only the comment text.
                """,
                icon: "text.bubble.fill",
                description: "Short inline code comment",
                isPredefined: true,
                useSystemInstructions: false,
                category: .coding
            ),
        ]
    }
}

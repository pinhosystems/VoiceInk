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

                PRESERVE EVERYTHING THE USER ASKED FOR:
                - If the user raised TWO or THREE distinct requests, the brief MUST contain all of them — never collapse multiple goals into one.
                - Render every distinct request as a separate item: bullet, numbered step, or its own "Task:" line.
                - Preserve every constraint, qualifier, edge case, and clarifying detail the user mentioned. Trim disfluencies (uh, um, restate-corrections, tangents), not substance.

                Format:
                - Imperative voice. Specific. No hedging.
                - Preserve file paths, function names, library names, commands EXACTLY as spoken.
                - Preserve numeric constraints (timeouts, limits, versions, line numbers).
                - When the user gives context AND a goal, separate them: brief context paragraph, then "Task:" line(s), then constraints.
                - Multiple distinct asks → numbered list under one "Tasks:" header, never merged into prose.

                Do NOT write code. Output the brief only — no preamble, no closing, no markdown fences.
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
                promptText: """
                Rewrite <TRANSCRIPT> with better clarity and flow.

                Preserve EVERY point, request, fact, name, date, number, and technical term exactly. Never drop, merge, or summarize away ideas the user expressed. Tone and intent stay intact. Output only the rewritten text.
                """,
                icon: "pencil.circle.fill",
                description: "Rewrite with better clarity",
                isPredefined: true,
                useSystemInstructions: true,
                category: .writing
            ),

            CustomPrompt(
                id: emailPromptId,
                title: "Email",
                promptText: """
                Rewrite <TRANSCRIPT> as an email: greeting, body, closing.

                Preserve every fact, name, date, number, action item, and distinct point the user mentioned — never drop or merge them. Body length follows the source: short asks stay 2–4 sentences; multi-topic dictation expands into separate short paragraphs or a bullet list rather than collapsing into one paragraph. Friendly tone unless the source clearly calls for formal.
                """,
                icon: "envelope.fill",
                description: "Professional email formatting",
                isPredefined: true,
                useSystemInstructions: true,
                category: .writing
            ),

            CustomPrompt(
                id: chatPromptId,
                title: "Chat",
                promptText: """
                Rewrite <TRANSCRIPT> as a short, informal chat message. Keep emojis. No greetings or sign-offs.

                Preserve every distinct point, fact, name, number, and link the user mentioned — chat shortness is about register, not about dropping content. Multiple ideas → multiple sentences or a short bulleted list, not a merged blob.
                """,
                icon: "bubble.left.and.bubble.right.fill",
                description: "Casual chat-style formatting",
                isPredefined: true,
                useSystemInstructions: true,
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
                - Preserve identifiers, file paths, numeric values, and every distinct rationale the user gave exactly — never drop a reason.

                Output only the comment text.
                """,
                icon: "text.bubble.fill",
                description: "Short inline code comment",
                isPredefined: true,
                useSystemInstructions: true,
                category: .coding
            ),
        ]
    }
}

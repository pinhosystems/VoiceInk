import Foundation

struct TemplatePrompt: Identifiable {
    let id: UUID
    let title: String
    let promptText: String
    let icon: PromptIcon
    let description: String
    let vocabularyDomains: [VocabularyDomain]
    let category: PromptCategory

    init(
        id: UUID,
        title: String,
        promptText: String,
        icon: PromptIcon,
        description: String,
        vocabularyDomains: [VocabularyDomain] = [.userVocabulary],
        category: PromptCategory = .writing
    ) {
        self.id = id
        self.title = title
        self.promptText = promptText
        self.icon = icon
        self.description = description
        self.vocabularyDomains = vocabularyDomains
        self.category = category
    }

    func toCustomPrompt() -> CustomPrompt {
        CustomPrompt(
            id: UUID(),
            title: title,
            promptText: promptText,
            icon: icon,
            description: description,
            isPredefined: false,
            vocabularyDomains: vocabularyDomains,
            category: category
        )
    }
}

enum PromptTemplates {
    static var all: [TemplatePrompt] {
        createTemplatePrompts()
    }

    /// Stable UUIDs for each template. Power Mode presets reference these
    /// to bind themselves to a specific prompt without depending on the
    /// localizable `title` field. Keep them stable across releases —
    /// rotating an ID forces every user-cloned prompt to lose its link.
    enum TemplateID {
        static let systemDefault   = UUID(uuidString: "0F0E0001-0000-0000-0000-000000000001")!
        static let chat            = UUID(uuidString: "0F0E0001-0000-0000-0000-000000000002")!
        static let email           = UUID(uuidString: "0F0E0001-0000-0000-0000-000000000003")!
        static let rewrite         = UUID(uuidString: "0F0E0001-0000-0000-0000-000000000004")!
        static let codeComment     = UUID(uuidString: "0F0E0001-0000-0000-0000-000000000010")!
        static let commitMessage   = UUID(uuidString: "0F0E0001-0000-0000-0000-000000000011")!
        static let prDescription   = UUID(uuidString: "0F0E0001-0000-0000-0000-000000000012")!
        static let codeReview      = UUID(uuidString: "0F0E0001-0000-0000-0000-000000000013")!
        static let taskPrompt      = UUID(uuidString: "0F0E0001-0000-0000-0000-000000000020")!
    }

    static func template(withID id: UUID) -> TemplatePrompt? {
        all.first { $0.id == id }
    }

    static func createTemplatePrompts() -> [TemplatePrompt] {
        [
            // MARK: - Writing
            TemplatePrompt(
                id: TemplateID.systemDefault,
                title: "System Default",
                promptText: "Clean <TRANSCRIPT>: fix grammar, drop fillers, collapse repetitions, resolve self-corrections, format lists when enumerated. Output only the cleaned text.",
                icon: "checkmark.seal.fill",
                description: "Default cleanup",
                category: .writing
            ),
            TemplatePrompt(
                id: TemplateID.rewrite,
                title: "Rewrite",
                promptText: "Rewrite <TRANSCRIPT> with better clarity and flow. Preserve meaning, tone, and facts. Output only the rewritten text.",
                icon: "pencil.circle.fill",
                description: "Rewrite with better clarity",
                category: .writing
            ),
            TemplatePrompt(
                id: TemplateID.email,
                title: "Email",
                promptText: "Rewrite <TRANSCRIPT> as an email: greeting, 2–4 sentence body, closing. Match the <TRANSCRIPT> language. Friendly tone unless clearly professional. Keep all facts, names, dates, action items.",
                icon: "envelope.fill",
                description: "Professional email formatting",
                category: .writing
            ),

            // MARK: - Chat
            TemplatePrompt(
                id: TemplateID.chat,
                title: "Chat",
                promptText: "Rewrite <TRANSCRIPT> as a short informal chat message. Keep emojis. No greetings or sign-offs.",
                icon: "bubble.left.and.bubble.right.fill",
                description: "Casual chat-style formatting",
                category: .chat
            ),

            // MARK: - Coding (output stays inside an editor)
            TemplatePrompt(
                id: TemplateID.codeComment,
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
                category: .coding
            ),
            TemplatePrompt(
                id: TemplateID.commitMessage,
                title: "Commit Message",
                promptText: """
                Rewrite <TRANSCRIPT> as a git commit message.

                Format:
                - Line 1: imperative summary, ≤72 characters, no trailing period.
                - Optional blank line + body of bullet points or short paragraphs explaining the *why*.
                - Preserve filenames, function names, and version numbers exactly.

                Output only the commit message — no preamble, no closing.
                """,
                icon: "checkmark.circle.fill",
                description: "Imperative commit summary + optional body",
                category: .coding
            ),
            TemplatePrompt(
                id: TemplateID.prDescription,
                title: "PR Description",
                promptText: """
                Rewrite <TRANSCRIPT> as a pull request description in markdown.

                Structure:
                ## Summary
                1–4 short bullets describing what changed and why.

                ## Test plan
                Bulleted checklist of things to verify before merging.

                Rules:
                - Preserve filenames, function names, library versions, and command-line flags exactly as spoken.
                - Imperative voice in the test plan ("Verify…", "Run…").
                - No emoji, no marketing tone.

                Output only the markdown body.
                """,
                icon: "doc.text.fill",
                description: "Summary + test plan markdown",
                category: .coding
            ),
            TemplatePrompt(
                id: TemplateID.codeReview,
                title: "Code Review",
                promptText: """
                Rewrite <TRANSCRIPT> as a concise pull-request review comment in markdown.

                Rules:
                - Terse. One short paragraph or a few bullets. No "Hi!", no closing pleasantries.
                - If multiple distinct points were raised, render them as a bulleted list.
                - Preserve filenames, function names, and identifiers exactly. Use inline `code spans` for them when natural.
                - When suggesting a change, lead with the suggestion in imperative voice.

                Output only the comment markdown.
                """,
                icon: "checklist",
                description: "Concise markdown review feedback",
                category: .coding
            ),

            // MARK: - AI Coding Agent (output is consumed by an LLM)
            TemplatePrompt(
                id: TemplateID.taskPrompt,
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
                category: .dev_ai
            ),
        ]
    }
}

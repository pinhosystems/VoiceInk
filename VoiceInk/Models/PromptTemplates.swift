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
        static let commitMessage   = UUID(uuidString: "0F0E0001-0000-0000-0000-000000000011")!
        static let prDescription   = UUID(uuidString: "0F0E0001-0000-0000-0000-000000000012")!
        static let codeReview      = UUID(uuidString: "0F0E0001-0000-0000-0000-000000000013")!
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
                promptText: """
                Clean <TRANSCRIPT>: fix grammar, drop true fillers (uh, um, hmm), collapse verbatim word-by-word repetitions, resolve self-corrections, format lists when the user clearly enumerates.

                NEVER drop content:
                - Preserve every distinct point, request, or detail the user made — if they raised two topics, output two topics.
                - Preserve facts, names, dates, numbers, technical terms, file paths, URLs, identifiers, and proper nouns exactly as spoken.
                - "Drop fillers" applies only to disfluencies, not to qualifiers, hedges, or clarifying phrases that carry meaning.

                Output only the cleaned text.
                """,
                icon: "checkmark.seal.fill",
                description: "Default cleanup",
                category: .writing
            ),

            // MARK: - Coding (output stays inside an editor)
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
        ]
    }
}

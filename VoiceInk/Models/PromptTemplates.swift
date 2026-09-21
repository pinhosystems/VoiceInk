import Foundation

struct TemplatePrompt: Identifiable {
    let id: UUID
    let title: String
    let promptText: String
    let icon: PromptIcon
    let description: String
    let triggerWords: [String]
    let vocabularyDomains: [VocabularyDomain]
    let category: PromptCategory

    init(
        id: UUID,
        title: String,
        promptText: String,
        icon: PromptIcon,
        description: String,
        triggerWords: [String] = [],
        vocabularyDomains: [VocabularyDomain] = [.userVocabulary],
        category: PromptCategory = .writing
    ) {
        self.id = id
        self.title = title
        self.promptText = promptText
        self.icon = icon
        self.description = description
        self.triggerWords = triggerWords
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
            triggerWords: triggerWords,
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
        static let meetingNotes    = UUID(uuidString: "0F0E0001-0000-0000-0000-000000000021")!
        static let statusUpdate    = UUID(uuidString: "0F0E0001-0000-0000-0000-000000000022")!
        static let bugReport       = UUID(uuidString: "0F0E0001-0000-0000-0000-000000000023")!
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

            TemplatePrompt(
                id: TemplateID.meetingNotes,
                title: "Meeting Notes",
                promptText: """
                Rewrite <TRANSCRIPT> as structured meeting notes in markdown.

                Structure (omit any empty section, use the localized headers matching the output language):
                ## Topics
                Short bullets — one per distinct topic discussed.
                ## Decisions
                Bullets for decisions actually made. Do not invent decisions that were not stated.
                ## Action items
                - [ ] checkbox bullets, one per task; include the owner when the user named one.

                Rules:
                - Preserve every distinct point, name, date, and number. Attribute statements to people when the user did.
                - Keep the original order within each section.
                - No preamble, no summary paragraph, no invented content.

                Output only the notes.
                """,
                icon: "person.2.fill",
                description: "Braindump into topics, decisions, and action items",
                triggerWords: ["meeting notes", "ata"],
                category: .writing
            ),

            TemplatePrompt(
                id: TemplateID.statusUpdate,
                title: "Status Update",
                promptText: """
                Rewrite <TRANSCRIPT> as a short status update (daily/standup style).

                Structure (omit any empty section, use the localized labels matching the output language):
                **Done:** what was completed.
                **Next:** what is planned.
                **Blocked:** blockers, naming who or what is blocking when stated.

                Rules:
                - Each section is one short sentence or up to 3 tight bullets.
                - Preserve ticket IDs, branch names, file paths, and technical terms exactly as spoken.
                - No greetings, no filler, no invented progress.

                Output only the update.
                """,
                icon: "chart.bar.fill",
                description: "Done / next / blocked standup summary",
                triggerWords: ["status update", "daily"],
                vocabularyDomains: [.userVocabulary, .technical],
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

            TemplatePrompt(
                id: TemplateID.bugReport,
                title: "Bug Report",
                promptText: """
                Rewrite <TRANSCRIPT> as a bug report in markdown.

                Structure (omit sections the user gave no information for, use the localized headers matching the output language):
                ## Summary
                One sentence stating the defect.
                ## Steps to reproduce
                Numbered list.
                ## Expected
                ## Actual
                ## Environment
                OS / app version / device, only if mentioned.

                Rules:
                - Preserve error messages, file paths, versions, and identifiers exactly as spoken; put error messages in inline `code spans`.
                - Do not invent steps or details the user did not state.

                Output only the markdown body.
                """,
                icon: "ant.fill",
                description: "Steps to reproduce, expected vs actual",
                triggerWords: ["bug report"],
                vocabularyDomains: [.userVocabulary, .technical],
                category: .coding
            ),
        ]
    }
}

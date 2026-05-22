import Foundation

struct TemplatePrompt: Identifiable {
    let id: UUID
    let title: String
    let promptText: String
    let icon: PromptIcon
    let description: String
    let vocabularyDomains: [VocabularyDomain]

    init(
        id: UUID,
        title: String,
        promptText: String,
        icon: PromptIcon,
        description: String,
        vocabularyDomains: [VocabularyDomain] = [.userVocabulary]
    ) {
        self.id = id
        self.title = title
        self.promptText = promptText
        self.icon = icon
        self.description = description
        self.vocabularyDomains = vocabularyDomains
    }

    func toCustomPrompt() -> CustomPrompt {
        CustomPrompt(
            id: UUID(),
            title: title,
            promptText: promptText,
            icon: icon,
            description: description,
            isPredefined: false,
            vocabularyDomains: vocabularyDomains
        )
    }
}

enum PromptTemplates {
    static var all: [TemplatePrompt] {
        createTemplatePrompts()
    }

    static func createTemplatePrompts() -> [TemplatePrompt] {
        [
            TemplatePrompt(
                id: UUID(),
                title: "System Default",
                promptText: """
                    - Clean <TRANSCRIPT>: fix grammar/spelling, drop fillers, collapse repetitions, resolve self-corrections.
                    - Honor "new line"/"new paragraph". Format lists when speaker counts or enumerates.
                    - Output only the cleaned text. No new facts.
                    """,
                icon: "checkmark.seal.fill",
                description: "Default cleanup"
            ),
            TemplatePrompt(
                id: UUID(),
                title: "Chat",
                promptText: """
                    - Rewrite <TRANSCRIPT> as a short informal chat message.
                    - Keep emojis. Expand only ambiguous shorthand (pq, vc, tb).
                    - No greetings, sign-offs, or commentary.
                    """,
                icon: "bubble.left.and.bubble.right.fill",
                description: "Casual chat-style formatting"
            ),
            TemplatePrompt(
                id: UUID(),
                title: "Email",
                promptText: """
                    - Rewrite <TRANSCRIPT> as an email: greeting, 2–4 sentence body, closing. Match the <TRANSCRIPT> language for both.
                    - Friendly tone unless <TRANSCRIPT> is clearly professional.
                    - Keep all facts, names, dates, action items. Never invent.
                    """,
                icon: "envelope.fill",
                description: "Professional email formatting"
            ),
            TemplatePrompt(
                id: UUID(),
                title: "Rewrite",
                promptText: """
                    - Rewrite <TRANSCRIPT> with better clarity and flow; preserve meaning, tone, facts.
                    - Fix grammar, drop fillers, format any lists.
                    - Output only the rewritten text.
                    """,
                icon: "pencil.circle.fill",
                description: "Rewrite with better clarity"
            )
        ]
    }
}

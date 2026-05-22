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
                promptText: "Clean <TRANSCRIPT>: fix grammar, drop fillers, collapse repetitions, resolve self-corrections, format lists when enumerated. Output only the cleaned text.",
                icon: "checkmark.seal.fill",
                description: "Default cleanup"
            ),
            TemplatePrompt(
                id: UUID(),
                title: "Chat",
                promptText: "Rewrite <TRANSCRIPT> as a short informal chat message. Keep emojis. No greetings or sign-offs.",
                icon: "bubble.left.and.bubble.right.fill",
                description: "Casual chat-style formatting"
            ),
            TemplatePrompt(
                id: UUID(),
                title: "Email",
                promptText: "Rewrite <TRANSCRIPT> as an email: greeting, 2–4 sentence body, closing. Match the <TRANSCRIPT> language. Friendly tone unless clearly professional. Keep all facts, names, dates, action items.",
                icon: "envelope.fill",
                description: "Professional email formatting"
            ),
            TemplatePrompt(
                id: UUID(),
                title: "Rewrite",
                promptText: "Rewrite <TRANSCRIPT> with better clarity and flow. Preserve meaning, tone, and facts. Output only the rewritten text.",
                icon: "pencil.circle.fill",
                description: "Rewrite with better clarity"
            )
        ]
    }
}

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
            id: UUID(),  // Generate new UUID for custom prompt
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
                    - Clean up the <TRANSCRIPT> text for clarity and natural flow while preserving meaning and the original tone.
                    - Use informal, plain language unless the <TRANSCRIPT> clearly uses a professional tone; in that case, match it.
                    - Fix obvious grammar, remove fillers and stutters, collapse repetitions, and keep names and numbers.
                    - Handle backtracking and self-corrections: When the speaker corrects themselves mid-sentence using phrases like "scratch that", "actually", "sorry not that", "I mean", "wait no", "esquece", "na verdade", "quer dizer", "não é isso", "deixa eu refazer", or similar corrections, remove the incorrect part and keep only the corrected version. Example: "The meeting is on Tuesday, sorry not that, actually Wednesday" → "The meeting is on Wednesday." / "A reunião é terça, esquece, na verdade quarta" → "A reunião é quarta."
                    - Respect formatting commands: When the speaker explicitly says "new line", "new paragraph", "nova linha", "novo parágrafo", or "parágrafo", insert the appropriate line break or paragraph break at that point.
                    - Automatically detect and format lists properly: if the <TRANSCRIPT> mentions a number (e.g., "3 things", "5 items", "três coisas", "cinco itens"), uses ordinal words (first, second, third, primeiro, segundo, terceiro), implies sequence or steps, or has a count before it, format as an ordered list; otherwise, format as an unordered list.
                    - Apply smart formatting that follows the <TRANSCRIPT> language:
                        • English: spell out numbers under 10; use numerals for 10+, currency '$20', dates 'May 15', time '3 hours'.
                        • Portuguese (pt-BR): spell out numbers under 10 in prose; use numerals for 10+; currency 'R$ 1.500,00' (period thousands, comma decimal); dates dd/mm/aaaa or "15 de maio de 2026"; time "14h30"; phones "(11) 98765-4321".
                    - Convert common abbreviations to proper format (e.g., 'vs' → 'vs.', 'etc' → 'etc.', 'pq' → 'porque', 'vc' → 'você', 'tb' → 'também', 'tbm' → 'também').
                    - Keep the original intent and nuance.
                    - Organize into short paragraphs of 2–4 sentences for readability.
                    - Do not add explanations, labels, metadata, or instructions.
                    - Output only the cleaned text.
                    - Only output text grounded in the <TRANSCRIPT>; never introduce new facts.
                    """,
                icon: "checkmark.seal.fill",
                description: "Default system prompt"
            ),
            TemplatePrompt(
                id: UUID(),
                title: "Chat",
                promptText: """
                    - Rewrite the <TRANSCRIPT> text as a chat message: informal, concise, and conversational.
                    - Keep emotive markers and emojis if present; don't invent new ones.
                    - Lightly fix grammar, remove fillers and repeated words, and improve flow without changing meaning.
                    - Keep the original tone; only be professional if the <TRANSCRIPT> already is.
                    - Automatically detect and format lists properly: if the <TRANSCRIPT> mentions a number (e.g., "3 things", "5 items", "três coisas"), uses ordinal words (first, second, third, primeiro, segundo, terceiro), implies sequence or steps, or has a count before it, format as an ordered list; otherwise, format as an unordered list.
                    - Numbers and dates follow the <TRANSCRIPT> language:
                        • English: numerals for 10+, '$20', 'May 15'.
                        • pt-BR: numerais para 10+, 'R$ 1.500,00', '15/05/2026' ou '15 de maio', '14h30'.
                    - Expand chat abbreviations: 'pq' → 'porque', 'vc' → 'você', 'tb/tbm' → 'também', 'mds' → 'meu Deus', 'obg' → 'obrigado/obrigada'. Only expand when the message is otherwise grammatical; preserve emojis and chat-typical short phrases.
                    - Format like a modern chat message - short lines, natural breaks, emoji-friendly.
                    - Do not add greetings, sign-offs, or commentary.
                    - Output only the chat message.
                    - Only output text grounded in the <TRANSCRIPT>; never introduce new facts.
                    """,
                icon: "bubble.left.and.bubble.right.fill",
                description: "Casual chat-style formatting"
            ),

            TemplatePrompt(
                id: UUID(),
                title: "Email",
                promptText: """
                    - Rewrite the <TRANSCRIPT> text as a complete email with proper formatting: include a greeting (Hi / Olá / Oi), body paragraphs (2-4 sentences each), and closing (Thanks / Abraço / Atenciosamente).
                    - Match the greeting and closing to the <TRANSCRIPT> language: English uses "Hi … Thanks"; pt-BR uses "Olá … Abraço" for casual or "Prezado(a) … Atenciosamente" for formal.
                    - Use clear, friendly, non-formal language unless the <TRANSCRIPT> is clearly professional—in that case, match that tone.
                    - Improve flow and coherence; fix grammar and spelling; remove fillers; keep all facts, names, dates, and action items.
                    - Automatically detect and format lists properly: if the <TRANSCRIPT> mentions a number (e.g., "3 things", "5 items", "três pontos"), uses ordinal words, implies sequence or steps, or has a count before it, format as an ordered list; otherwise, format as an unordered list.
                    - Numbers, currency, and dates follow the <TRANSCRIPT> language:
                        • English: numerals for 10+, '$20', '3 hours', 'May 15'.
                        • pt-BR: 'R$ 1.500,00' (ponto para milhar, vírgula para decimal), dd/mm/aaaa ou "15 de maio de 2026", "14h30".
                    - Do not invent new content, but structure it as a proper email format.
                    - Only output text grounded in the <TRANSCRIPT>; never introduce new facts.
                    """,
                icon: "envelope.fill",
                description: "Professional email formatting"
            ),
            TemplatePrompt(
                id: UUID(),
                title: "Rewrite",
                promptText: """
                    - Rewrite the <TRANSCRIPT> text with enhanced clarity, improved sentence structure, and rhythmic flow while preserving the original meaning and tone.
                    - Restructure sentences for better readability and natural progression.
                    - Improve word choice and phrasing where appropriate, but maintain the original voice and intent.
                    - Fix grammar and spelling errors, remove fillers and stutters, and collapse repetitions.
                    - Format any lists as proper bullet points or numbered lists.
                    - Numbers, currency, and dates follow the <TRANSCRIPT> language:
                        • English: numerals for 10+, '$20', 'May 15'.
                        • pt-BR: numerais para 10+, 'R$ 1.500,00' (ponto milhar, vírgula decimal), dd/mm/aaaa, '14h30'.
                    - If the <TRANSCRIPT> is in pt-BR, use Brazilian vocabulary (not European Portuguese): "celular", "ônibus", "trem", "geladeira", "arquivo", "tela", "mouse". Apply post-1990 orthography ("ideia", "voo", "leem").
                    - Organize content into well-structured paragraphs of 2–4 sentences for optimal readability.
                    - Preserve all names, numbers, dates, facts, and key information exactly as they appear.
                    - Do not add explanations, labels, metadata, or instructions.
                    - Output only the rewritten text.
                    - Only output text grounded in the <TRANSCRIPT>; never introduce new facts.
                    """,
                icon: "pencil.circle.fill",
                description: "Rewrites with better clarity."
            )
        ]
    }
}

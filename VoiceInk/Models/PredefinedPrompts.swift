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
    // 0005 was "Email"; it kept its UUID when it became "Email — Formal"
    // so persisted selections and Power Mode references still resolve.
    static let emailPromptId       = UUID(uuidString: "00000000-0000-0000-0000-000000000005")!
    static let chatPromptId        = UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
    // 00000000-...-0007 was Code Comment — removed; the slot is kept
    // unused as a tombstone so future predefined IDs don't reuse it.
    // 00000000-...-0008 was Task Prompt (PT-BR) — replaced by the
    // runtime TechTermSalvage block injected by AIEnhancementService
    // based on the user's selected STT language. Same tombstone reason.
    static let emailCasualPromptId = UUID(uuidString: "00000000-0000-0000-0000-000000000009")!

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
                description: "Improves clarity and accuracy of the transcription",
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
                Clean up <TRANSCRIPT> so it reads as a task brief for an AI coding agent (Claude Code, Cursor, Copilot Chat). The output has two parts: the user's words in flowing prose, then an actionable task summary below.

                Language: write the result in the same language as the audio (see <AUDIO_LANGUAGE>). When the audio language is not English but the user mixed in English tech jargon, follow the <TECH_TERM_SALVAGE> table to restore canonical English spelling for those terms — never translate the salvaged terms back.

                SECTION 1 — Prose (the user's brief, kept close to original):
                - Drop only disfluencies (uh, um, hmm, verbatim word-by-word repetitions, mid-sentence self-corrections like "no wait, I mean…"). Resolve the correction in place.
                - Keep the user's wording, examples, qualifiers, hedges, and asides. They carry meaning.
                - Keep questions as questions ("Can we…?", "Should this…?", "Por que…?"). Do not flip them into imperative commands.
                - Keep statements as statements when the user is describing context or reporting state. Do not invent action verbs the user did not use.
                - Mixed turns are normal — context sentences, questions, and tasks coexist in the same brief.
                - Preserve every distinct point. If the user raised two or three things, all of them appear in the same order.
                - Preserve file paths, function names, library names, commands, version numbers, and other identifiers EXACTLY as spoken.
                - Flowing prose by default. No imposed labels. No marketing language. No padding. No "Please" / "Could you". No artificial summaries inside this section.

                SECTION 2 — Tasks (your concise actionable summary):
                - After the prose, add a blank line and then the header "Tasks:" (or the localized equivalent — "Tasks:", "Tarefas:", "Tareas:", etc., matching <AUDIO_LANGUAGE>).
                - Under the header, list the actionable items as short imperative bullets, one per line, starting with "- ".
                - Each bullet is a single concrete action ("Add X", "Fix Y", "Investigate Z"). Group obviously related sub-steps under one bullet rather than fragmenting.
                - Skip questions, context, and reported state — they belong only in the prose. The Tasks list is for things the agent is being asked to DO.
                - If the user raised zero actionable items (pure questions, pure context dump), omit Section 2 entirely — no header, no empty list.

                SUPPRESSION COMMAND:
                - The user may suppress Section 2 by speaking a control phrase at the very start or end of the audio. Recognize, case-insensitive, any of: "no tasks", "skip tasks", "no summary", "skip summary", "sem tasks", "sem resumo", "pular tasks", "só o texto", "apenas texto", "only text", "only prose".
                - When detected, strip the control phrase from the prose AND omit Section 2 (no header, no bullets). Output the cleaned prose only.

                Do NOT write code. Do NOT add anything the user did not say (Tasks bullets are a summary of what they DID say, not invented work). Output the cleaned brief only — no preamble, no closing, no markdown fences.
                """,
                icon: "brain.head.profile",
                description: "Dictated brief in the user's words, followed by a concise task summary (suppressible by voice)",
                isPredefined: true,
                triggerWords: ["tarefa", "task"],
                useSystemInstructions: false,
                vocabularyDomains: [.userVocabulary, .technical],
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
                title: "Email — Formal",
                promptText: """
                Rewrite <TRANSCRIPT> as a formal, professional email: greeting, body, closing.

                If the user dictates a subject, put it first on its own line as "Subject:" (or the localized equivalent — "Assunto:", "Asunto:" — matching the output language).

                Formal register: full sentences, no contractions, no slang; courteous but direct. Greeting like "Dear …"/"Prezado(a) …" when a recipient is named, a neutral "Hello,"/"Olá," otherwise. Closing like "Best regards"/"Atenciosamente".

                Preserve every fact, name, date, number, action item, and distinct point the user mentioned — never drop or merge them. Body length follows the source: short asks stay 2–4 sentences; multi-topic dictation expands into separate short paragraphs or a bullet list rather than collapsing into one paragraph.
                """,
                icon: "envelope.fill",
                description: "Formal, professional email formatting",
                isPredefined: true,
                triggerWords: ["email formal", "formal email", "e-mail formal", "email", "e-mail"],
                useSystemInstructions: true,
                category: .writing
            ),

            CustomPrompt(
                id: emailCasualPromptId,
                title: "Email — Casual",
                promptText: """
                Rewrite <TRANSCRIPT> as a friendly, casual email: short greeting, body, brief sign-off.

                If the user dictates a subject, put it first on its own line as "Subject:" (or the localized equivalent — "Assunto:", "Asunto:" — matching the output language).

                Relaxed register: contractions are fine, first names, light tone — but still an email, not a chat message. No emojis unless the user dictated them.

                Preserve every fact, name, date, number, action item, and distinct point the user mentioned — never drop or merge them. Body length follows the source: short asks stay 2–4 sentences; multi-topic dictation expands into separate short paragraphs or a bullet list rather than collapsing into one paragraph.
                """,
                icon: "envelope.open.fill",
                description: "Friendly, casual email formatting",
                isPredefined: true,
                triggerWords: ["email casual", "casual email", "email informal", "informal email", "e-mail casual", "e-mail informal"],
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
                triggerWords: ["chat", "mensagem"],
                useSystemInstructions: true,
                category: .chat
            ),
        ]
    }
}

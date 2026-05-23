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
    /// PT-BR variant of Task Prompt. Same structured-task-brief output
    /// as `taskPromptId`, but with an explicit phonetic-misspelling
    /// table for English dev jargon dictated in Portuguese (commit,
    /// push, pull request, rebase, ...) and an unambiguous rule to
    /// keep the brief in Portuguese instead of translating it.
    static let taskPromptCodePtBRId = UUID(uuidString: "00000000-0000-0000-0000-000000000008")!

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
                id: taskPromptCodePtBRId,
                title: "Task Prompt (PT-BR)",
                promptText: """
                Converta <TRANSCRIPT> em um brief de tarefa claro e estruturado para um agente de IA de código (Claude Code, Cursor, Copilot Chat).

                IDIOMA DO BRIEF: PORTUGUÊS (pt-BR).
                O usuário está ditando em português brasileiro. O brief DEVE permanecer em português. NÃO traduza para inglês. Apenas termos técnicos canônicos em inglês permanecem em inglês (commit, push, merge, deploy, etc.) — o restante é português.

                TERMOS TÉCNICOS EM INGLÊS DENTRO DE FALA PT-BR:
                Devs misturam jargão técnico em inglês ao falar. O STT frequentemente erra e escreve a versão fonética em português. Detecte e CORRIJA para a grafia canônica em inglês quando o contexto for técnico:

                | Ouvido (fonético PT) | Correto (canônico EN) |
                | --- | --- |
                | comêti, comêtchi, kometi, comêchi | commit |
                | puxe (em contexto git), puch | push |
                | pul, pulhequesti, pulrequesti, pulrequest | pull request |
                | mergi, mêrgi, merdge | merge |
                | brãnchi, brãnche, brãntche | branch |
                | rebeisi, rebeise, rebêisi | rebase |
                | repô, hepô | repo |
                | chécouti, tchécauti, tchekauti | checkout |
                | deploi (em git/infra) | deploy |
                | taipiscripti, taipscripti | TypeScript |
                | djavaiscripti, javaiscripti | JavaScript |
                | enepeeme, enpeeme | npm |
                | iuseteit, iusefect | useState, useEffect |
                | ridiucs, rêducs | Redux |
                | búqui (em web context) | hook |
                | hooky | hook (singular) |
                | callbéqui | callback |
                | mídiuér, mídiouér | middleware |
                | enpoint, indpointi | endpoint |
                | api (deletrear A-P-I, não "ápi") | API |
                | jeisson, jésson | JSON |
                | ésquema (em DB) | schema |
                | querê, querê pê | query |
                | builde, buildi | build |
                | runtaimi | runtime |
                | bãndoll, bãndle | bundle |
                | quontêiner | container |

                Use também `<CUSTOM_VOCABULARY>` (quando presente) como referência de grafia para nomes próprios, bibliotecas e identificadores.

                PRESERVE TUDO QUE O USUÁRIO PEDIU:
                - Se o usuário fez DUAS ou TRÊS solicitações distintas, o brief DEVE conter TODAS — nunca colapse múltiplos objetivos em um só.
                - Renderize cada solicitação distinta como item separado: bullet, passo numerado, ou linha "Task:" própria.
                - Preserve toda restrição, qualificador, edge case e detalhe esclarecedor. Corte disfluências (uh, é, então, tipo, restate-corrections, tangentes), nunca substância.

                FORMATO:
                - Voz imperativa em português ("Implemente", "Adicione", "Refatore").
                - Preserve EXATAMENTE: caminhos de arquivo, nomes de funções, nomes de bibliotecas, comandos shell, números (timeouts, limites, versões, números de linha).
                - Quando o usuário der contexto E objetivo, separe: parágrafo curto de contexto, depois linha(s) "Task:" / "Tarefa:", depois restrições.
                - Múltiplas tarefas → lista numerada sob um único cabeçalho "Tarefas:", nunca prosa colada.

                NÃO escreva código. Saída apenas o brief — sem preâmbulo, sem fechamento, sem cercas de markdown.
                """,
                icon: "brain.head.profile",
                description: "Brief de tarefa em pt-BR — corrige termos técnicos EN ouvidos foneticamente",
                isPredefined: true,
                useSystemInstructions: false,
                vocabularyDomains: [.userVocabulary, .technical, .brazilian],
                category: .dev_ai
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

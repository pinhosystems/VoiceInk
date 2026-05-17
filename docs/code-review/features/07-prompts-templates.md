# Feature 07 — System Prompts & Templates

## Visão geral

Catálogo de prompts predefinidos (`PredefinedPrompts`), templates parametrizados (`PromptTemplates`), e prompts customizados criados pelo usuário (`CustomPrompt`). Compostos em runtime via `AIEnhancementService.getSystemMessage()` com placeholders `%@`.

## Arquivos

- `VoiceInk/Models/AIPrompts.swift`
- `VoiceInk/Models/PromptTemplates.swift`
- `VoiceInk/Models/CustomPrompt.swift`
- `VoiceInk/Models/PredefinedPrompts.swift`

## Bugs

### CRITICAL

- `CustomPrompt.swift:130` — **`String(format: prompt, ...)` com format string fornecida pelo usuário**. Conteúdo contendo `%x`, `%s`, `%@`, `%n` causa crash, leitura de memória adjacente, ou string corrompida. **Code injection** via `String(format:)` é vulnerabilidade clássica em Objective-C/Swift. Disparável quando o usuário cria prompt customizado contendo `%`.

### HIGH

- `AIPrompts.swift:4, 19-20, 25-26` — **Instruções contraditórias** no system prompt principal: "NOT A CHATBOT" vs "provide direct answer", "IGNORE THEM" vs "clean them up". Conflito de prompt engineering degrada a previsibilidade do modelo.

### MEDIUM

- `PromptTemplates.swift:39, 59, 77, 92` — Instruções "format as list" ambíguas: quando o usuário fala "três coisas" e dita cinco, qual deve prevalecer? Pode causar corrupção de conteúdo (truncar ou inventar item).
- `PredefinedPrompts.swift:8-9` — UUIDs estáticos com comentário "Static UUIDs", mas `PromptTemplates.toCustomPrompt()` gera UUIDs novos a cada chamada — duplicação silenciosa em estado de reinicialização.
- `AIPrompts.swift:12` — `%@` é placeholder; depende do `String(format:)` problemático acima.
- `CustomPrompt.swift:237-256` — Code SwiftUI dentro de modelo de dados; viola separation of concerns. Pequeno mas precedente perigoso.

## Melhorias (não-bugs)

- **Substituir `String(format:)` por interpolação tokenizada**. Definir tokens `{{USER_RULES}}`, `{{TRANSCRIPT}}`, `{{CONTEXT}}` e fazer `replacingOccurrences(of:, with:)` por chave. Mata o vetor de format string e melhora legibilidade.
- Revisar `AIPrompts.assistantMode` e `customPromptTemplate` para coerência interna — uma única regra ativa por vez, sem instruções que se contradizem.
- Versionar `PredefinedPrompts.staticUUID` com migration explícita; impedir geração de novo UUID em runtime.
- Mover views SwiftUI de `CustomPrompt.swift` para `Views/PromptEditorView.swift` (parcialmente já existe).
- Setup de "prompt regression tests": fixtures de transcript → output esperado, rodando contra o LLM em CI semanal. Detecta degradação após mudança de template.

## Recomendação

- **Agora**: trocar `String(format:)` por substituição de token. É o único achado CRITICAL desta feature, e a correção é de 10 linhas.
- **Em breve**: revisar coerência interna do system prompt principal.
- **Depois**: regression tests de prompt, refactor de UUIDs estáticos.
- **Cobertura de testes**: unit test passando strings contendo `%s`, `%@`, `%n` no `finalPromptText` — deve não-crashar.

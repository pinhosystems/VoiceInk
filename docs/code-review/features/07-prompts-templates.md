# Feature 07 — System Prompts & Templates

## Visão geral

Catálogo de prompts predefinidos (`PredefinedPrompts`), templates parametrizados (`PromptTemplates`), e prompts customizados criados pelo usuário (`CustomPrompt`). Compostos em runtime via `AIEnhancementService.getSystemMessage()` com placeholders `%@`.

## Arquivos

- `VoiceInk/Models/AIPrompts.swift`
- `VoiceInk/Models/PromptTemplates.swift`
- `VoiceInk/Models/CustomPrompt.swift`
- `VoiceInk/Models/PredefinedPrompts.swift`

## Bugs

### HIGH

- `AIPrompts.swift:4, 19-20, 25-26` — **Instruções contraditórias** no system prompt principal: "NOT A CHATBOT" vs "provide direct answer", "IGNORE THEM" vs "clean them up". Conflito de prompt engineering degrada a previsibilidade do modelo.

### MEDIUM

- `PromptTemplates.swift:39, 59, 77, 92` — Instruções "format as list" ambíguas: quando o usuário fala "três coisas" e dita cinco, qual deve prevalecer? Pode causar corrupção de conteúdo (truncar ou inventar item).
- `PredefinedPrompts.swift:8-9` — UUIDs estáticos com comentário "Static UUIDs", mas `PromptTemplates.toCustomPrompt()` gera UUIDs novos a cada chamada — duplicação silenciosa em estado de reinicialização.
- `CustomPrompt.swift:237-256` — Code SwiftUI dentro de modelo de dados; viola separation of concerns. Pequeno mas precedente perigoso.

## Falsos positivos da auditoria original

- **~~`CustomPrompt.swift:130` — `String(format:)` code injection~~ (não procede).** A format string é `AIPrompts.customPromptTemplate`, definida no source (linhas 2-34 de `AIPrompts.swift`, com exatamente um `%@` na linha 14). O valor do usuário (`self.promptText`) entra como **argumento de substituição**, não como format string. `String(format:)` não re-interpreta o conteúdo de um argumento `%@` como format codes — `String(format: "%@", "%s")` produz literalmente `"%s"`. O vetor real de format-string injection exige que a STRING DE FORMATO venha do usuário, o que não acontece aqui. A correção via tokenização ainda é desejável por robustez (resiliente a mudanças futuras no template que adicionem outros `%@`), mas não é uma vulnerabilidade.

## Melhorias (não-bugs)

- Substituir `String(format:)` por substituição de token (`{{USER_RULES}}`) como melhoria de robustez/legibilidade. Não é fix de segurança, mas blinda contra mudanças futuras no template que ajustem o número de placeholders.
- Revisar `AIPrompts.assistantMode` e `customPromptTemplate` para coerência interna — uma única regra ativa por vez, sem instruções que se contradizem.
- Versionar `PredefinedPrompts.staticUUID` com migration explícita; impedir geração de novo UUID em runtime.
- Mover views SwiftUI de `CustomPrompt.swift` para `Views/PromptEditorView.swift` (parcialmente já existe).
- Setup de "prompt regression tests": fixtures de transcript → output esperado, rodando contra o LLM em CI semanal. Detecta degradação após mudança de template.

## Recomendação

- **Em breve**: revisar coerência interna do system prompt principal.
- **Depois**: regression tests de prompt, refactor de UUIDs estáticos, tokenização do template.
- **Cobertura de testes**: unit test do `finalPromptText` com strings contendo `%s`/`%@`/`%n` — deve manter o conteúdo literal e não crashar (confirmado: o comportamento atual já passa).

# Feature 06 — AI Enhancement (pós-processamento)

## Visão geral

Após a transcrição, opcionalmente envia o texto a um LLM (OpenAI, Anthropic, Gemini, Groq, OpenRouter, Ollama, Mistral, xAI, Custom, ou CLI local — Claude/Codex/Pi) com um system prompt configurável. Suporta contextos extras (clipboard, screen OCR, selected text).

## Arquivos

- `VoiceInk/Services/AIEnhancement/AIEnhancementService.swift`
- `VoiceInk/Services/AIEnhancement/AIService.swift`
- `VoiceInk/Services/AIEnhancement/LocalCLIService.swift`
- `VoiceInk/Services/AIEnhancement/AIEnhancementOutputFilter.swift`
- `VoiceInk/Services/AIEnhancement/ReasoningConfig.swift`
- `VoiceInk/Services/OllamaService.swift`
- `VoiceInk/Services/SelectedTextService.swift`
- `VoiceInk/Services/PromptDetectionService.swift`

## Bugs

### CRITICAL

- `LocalCLIService.swift:121-124` — **Shell injection**. `systemPrompt` e `userPrompt` (fornecidos pelo usuário) são interpolados em string de comando shell. Conteúdo com `$`, backticks, `;`, `|`, ou `&&` é executado. Mesmo num app local-only, isso é vetor de exploração via gravação maliciosa enviada por terceiro com `aiEnhancementOutputFilter` desabilitado.

### HIGH

- `AIEnhancementService.swift:257` — **`allPrompts.first!`** force-unwrap. Em estado limpo ou após migration falha, `allPrompts` pode estar vazio → crash. Deveria ter fallback hardcoded para "Default" prompt.
- `AIService.swift:243` — Condição `(selectedProvider == .ollama && !selectedModel.isEmpty)` redundante e confusa; lógica de fallback em modelo vazio não é clara, pode levar a "configurado mas não usável".
- `PromptDetectionService.swift:153-177` — Duplo loop `stripLeading`/`stripTrailing` pode comer palavra válida quando a trigger word aparece em ambos os lados. Caso real: ditar "ok corrige isso ok" com trigger "ok" remove duas vezes.

### MEDIUM

- `AIEnhancementService.swift:73-79` — `customPrompts` com `didSet` chamando `JSONEncoder` sem tratamento de erro; falhas de persistência são silenciosas.
- `AIEnhancementService.swift:196-200, 209-213, 223-226` — Context wrapping chama `SelectedTextService` 3x em série sem cache; cada chamada faz round-trip via Accessibility API e tem latência mensurável.
- `AIEnhancementService.swift:322` — `hasPrefix("gpt-5")` decide temperatura; nome futuro de modelo quebra a heurística.
- `AIService.swift:275-276` — Legacy migration `"GROQ" → "Groq"` case-sensitive; variações tipográficas em UserDefaults antigo bloqueiam.
- `LocalCLIService.swift:52-56` — Timeout < 5 silenciosamente reajustado para 5; usuário pensa que setou 0.5 mas não.
- `LocalCLIService.swift:199` — Fallback de PATH `/usr/bin:/bin:/usr/sbin:/sbin` ignora `/usr/local/bin` e `/opt/homebrew/bin` — Claude/Codex instalados via Homebrew não são encontrados.
- `AIEnhancementOutputFilter.swift:13-16` — `NSRegularExpression` criado em loop a cada chamada; compilação de regex é cara, deveria ser `static let` pré-compilado.
- `OllamaService.swift:61` — Modelo selecionado some do refresh? Muda silenciosamente para o primeiro disponível sem avisar.
- `OllamaService.swift:78-86` — `think: false` hardcoded; deveria respeitar `ReasoningConfig` do usuário.
- `PromptDetectionService.swift:86` — Usa `triggerWord.count` (UTF-16 code units) em vez de grapheme cluster count; emojis e combining marks contam errado e o slice fica off-by-N.
- `PromptDetectionService.swift:102, 140` — Regex `^[,\\.!\\?;:\\s]+` não cobre pontuação localizada («», „", 「」, etc.).

### LOW

- `ReasoningConfig.swift:32-40, 47-50` — Nomes de modelo hardcoded sem versionamento; "gpt-oss-120b" pode ser renomeado upstream e a config some.
- `AIEnhancementOutputFilter.swift:7-9` — Regex com `(?s)` (dotall) em texto longo é caro; considerar trimming antecipado.

## Melhorias (não-bugs)

- **Hardening de `LocalCLIService`**: passar prompt via `stdin` em vez de interpolação. `Process.standardInput` + `Pipe` é a forma idiomática e mata o vetor de injection.
- Cache de `SelectedTextService` por sessão (timestamp+content invalidation): elimina 2 das 3 round-trips na captura de contexto.
- Pré-compilar todos os `NSRegularExpression` como `static let` em qualquer filtro que rode em hot path.
- Suportar discovery dinâmica de PATH via `launchctl getenv PATH` + leitura de `~/.zshrc` (com warning explícito do que está checando), em vez de PATH hardcoded.
- Substituir `String.count` por `String.unicodeScalars.count` ou `.precomposedStringWithCanonicalMapping` antes de slice no `PromptDetectionService`.
- Padronizar fallback de prompt: se `allPrompts.isEmpty`, recriar a partir de `PredefinedPrompts` em vez de force-unwrap.

## Recomendação

- **Agora**: corrigir shell injection em `LocalCLIService` (stdin); eliminar `allPrompts.first!`.
- **Em breve**: cache de SelectedText, normalização de regex de pontuação, `think` respeitando ReasoningConfig.
- **Depois**: PATH discovery dinâmica, versionamento de model names em ReasoningConfig.
- **Cobertura de testes**: golden-master de PromptDetectionService com strings contendo emojis, RTL, pontuação localizada; mock de SelectedTextService.

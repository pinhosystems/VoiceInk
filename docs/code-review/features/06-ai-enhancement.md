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

### HIGH

- ~~`AIEnhancementService.swift:257` — `allPrompts.first!` force-unwrap.~~ **Resolvido em PR #10.**
- `AIService.swift:243` — Condição `(selectedProvider == .ollama && !selectedModel.isEmpty)` redundante e confusa; lógica de fallback em modelo vazio não é clara, pode levar a "configurado mas não usável".
- `PromptDetectionService.swift:153-177` — Duplo loop `stripLeading`/`stripTrailing` pode comer palavra válida quando a trigger word aparece em ambos os lados. Caso real: ditar "ok corrige isso ok" com trigger "ok" remove duas vezes.

### MEDIUM

- `AIEnhancementService.swift:73-79` — `customPrompts` com `didSet` chamando `JSONEncoder` sem tratamento de erro; falhas de persistência são silenciosas.
- `AIEnhancementService.swift:196-200, 209-213, 223-226` — Context wrapping chama `SelectedTextService` 3x em série sem cache; cada chamada faz round-trip via Accessibility API e tem latência mensurável.
- `AIEnhancementService.swift:322` — `hasPrefix("gpt-5")` decide temperatura; nome futuro de modelo quebra a heurística.
- `AIService.swift:275-276` — Legacy migration `"GROQ" → "Groq"` case-sensitive; variações tipográficas em UserDefaults antigo bloqueiam.
- `LocalCLIService.swift:52-56` — Timeout < 5 silenciosamente reajustado para 5; usuário pensa que setou 0.5 mas não.
- `AIEnhancementOutputFilter.swift:13-16` — `NSRegularExpression` criado em loop a cada chamada; compilação de regex é cara, deveria ser `static let` pré-compilado.
- `OllamaService.swift:61` — Modelo selecionado some do refresh? Muda silenciosamente para o primeiro disponível sem avisar.
- `OllamaService.swift:78-86` — `think: false` hardcoded; deveria respeitar `ReasoningConfig` do usuário.
- `PromptDetectionService.swift:86` — Usa `triggerWord.count` (UTF-16 code units) em vez de grapheme cluster count; emojis e combining marks contam errado e o slice fica off-by-N.
- `PromptDetectionService.swift:102, 140` — Regex `^[,\\.!\\?;:\\s]+` não cobre pontuação localizada («», „", 「」, etc.).

### LOW

- `ReasoningConfig.swift:32-40, 47-50` — Nomes de modelo hardcoded sem versionamento; "gpt-oss-120b" pode ser renomeado upstream e a config some.
- `AIEnhancementOutputFilter.swift:7-9` — Regex com `(?s)` (dotall) em texto longo é caro; considerar trimming antecipado.

## Falsos positivos da auditoria original

Investigação aprofundada durante a PR C revelou que dois achados listados como críticos não são vulnerabilidades reais:

- **~~`LocalCLIService.swift:121-124` — Shell injection~~ (não procede).** Os prompts são passados ao subprocess via variáveis de ambiente (`VOICEINK_SYSTEM_PROMPT`, `VOICEINK_USER_PROMPT`, `VOICEINK_FULL_PROMPT`) e via stdin (linhas 122-145). Os templates pré-definidos usam `"$VAR"` (aspas duplas) — zsh expande dentro de aspas duplas SEM word splitting, command substitution ou re-interpretação, então conteúdo como `;`, `$()`, backticks na transcrição vai literal para o argumento do comando, não para o shell. A única vulnerabilidade seria o usuário escrever um `commandTemplate` malicioso (ex.: `eval "$VOICEINK_FULL_PROMPT"`), o que é o usuário se atacar.
- **~~`LocalCLIService.swift:199` — PATH ignora Homebrew~~ (não procede).** O código já faz discovery via interactive login shell (`zsh -ilc`) — linhas 188-201, função `discoverPATHFromInteractiveLoginShell()`. O fallback hardcoded só dispara se o shell discovery falhar.

## Melhorias (não-bugs)

- Cache de `SelectedTextService` por sessão (timestamp+content invalidation): elimina 2 das 3 round-trips na captura de contexto.
- Pré-compilar todos os `NSRegularExpression` como `static let` em qualquer filtro que rode em hot path.
- Substituir `String.count` por `String.unicodeScalars.count` ou `.precomposedStringWithCanonicalMapping` antes de slice no `PromptDetectionService`.

## Recomendação

- **Em breve**: cache de SelectedText, normalização de regex de pontuação, `think` respeitando ReasoningConfig.
- **Depois**: versionamento de model names em ReasoningConfig.
- **Cobertura de testes**: golden-master de PromptDetectionService com strings contendo emojis, RTL, pontuação localizada; mock de SelectedTextService.

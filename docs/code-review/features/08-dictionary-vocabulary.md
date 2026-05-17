# Feature 08 — Dicionário / Vocabulário / Word Replacement

## Visão geral

Três conceitos relacionados: (a) `VocabularyWord` — termos customizados enviados como contexto a providers que suportam (Deepgram, Assembly, etc.); (b) `WordReplacement` — substituições pós-transcrição ("VS code" → "VS Code"); (c) Filler words removidos opcionalmente.

## Arquivos

- `VoiceInk/Models/VocabularyWord.swift`
- `VoiceInk/Models/WordReplacement.swift`
- `VoiceInk/Models/LanguageDictionary.swift`
- `VoiceInk/Services/DictionaryService.swift`
- `VoiceInk/Services/CustomVocabularyService.swift`
- `VoiceInk/Transcription/Processing/WordReplacementService.swift`
- `VoiceInk/Transcription/Processing/FillerWordManager.swift`
- `VoiceInk/Transcription/Processing/WhisperTextFormatter.swift`
- `VoiceInk/Transcription/Processing/TranscriptionOutputFilter.swift`

## Bugs

### HIGH

- `WordReplacementService.swift:42` — **Lookarounds `(?<![a-zA-Z0-9])` não cobrem unicode**. Palavras com acentos (português, espanhol, francês, alemão) e RTL (árabe, hebraico) **não disparam o replacement**. "café" vira `[a-zA-Z0-9]+` apenas como "caf" + "é", e a regra silenciosamente não dispara. Bug funcional em qualquer idioma com diacríticos.

### MEDIUM

- `WordReplacementService.swift:64-81` — Lookarounds aplicados N vezes (uma por replacement) sobre o texto inteiro: O(n*m) onde n=qtd replacements e m=tamanho do texto. Em usuários com 100+ replacements e transcript longa, mensurável.
- `TranscriptionOutputFilter.swift:42` — `NSRegularExpression.escapedPattern(for:)` escapa apenas regex meta; padrão frágil mas correto no uso atual.
- `TranscriptionOutputFilter.swift:142-145` — Múltiplas `replacingOccurrences` em cascata; poderia ser 1 regex com alternation.
- `FillerWordManager.swift:6-9` — Lista de filler words só em **inglês** (`um`, `uh`, `like`, ...). Em português `né`, `tipo`, `sabe`, `daí` não existem na lista — feature inútil para usuário PT-BR.

### LOW

- `LanguageDictionary.swift` — Mapeamento de códigos de idioma estático; pode estar desatualizado em relação ao que o `LLMkit` aceita por provider.
- `CustomVocabularyService.swift` — Sem deduplicação case-insensitive entre vocab e word replacements.

## Melhorias (não-bugs)

- **Trocar lookarounds por boundary semântico via `CharacterSet`**: usar `\b` do `NSRegularExpression` com a opção `.useUnicodeWordBoundaries` (que existe) ou construir manualmente com `\p{L}` e `\p{N}` (Unicode letter/number classes).
- Compile-and-cache de cada `NSRegularExpression` no `WordReplacementService` (atualmente compila a cada call).
- Listas de filler words **por idioma**, lidas do `LanguageDictionary` baseado em `SelectedLanguage`. Default em inglês mas extensível.
- Validação que impede o usuário de adicionar replacement com `from == to` (não-op silencioso hoje).
- Validação de duplicidade case-insensitive em `VocabularyWord` no service (parcialmente existe; revisar consistência).

## Recomendação

- **Agora**: trocar lookarounds em `WordReplacementService:42` por unicode-aware. Crítico para qualquer usuário não-anglófono — e o público alvo (incluindo PT-BR) é multinacional.
- **Em breve**: filler words por idioma; cache de regex compilada.
- **Depois**: refactor do `TranscriptionOutputFilter` para regex única.
- **Cobertura de testes**: replacements aplicados sobre strings contendo "café", "señor", "naïve", "résumé" — assertir match.

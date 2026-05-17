# Resumo Executivo

## Veredicto

VoiceInk tem **arquitetura razoável** (camadas claras, protocolos para abstração de providers, Swift moderno com async/await), mas **disciplina de implementação irregular**. A maior fragilidade do projeto não é nenhum módulo específico — é a **ausência total de cobertura de testes automatizados em pipelines críticos** (áudio, transcrição, enhancement). Isso explica por que bugs estruturais (header de WAV hardcoded, regex destrutivo, normalização per-chunk, etc.) chegaram à produção e só foram caçados empiricamente.

A app funciona, mas opera no limite da segurança: cada mudança de provider, cada update de SDK, e cada refactor pequeno corre risco real de regressão silenciosa.

## Top riscos atuais (após revisão pós-PRs)

Ordem aproximada por impacto. Status atualizado conforme PRs mergeadas.

1. **CRITICAL — Race condition em audio callback**. `CoreAudioRecorder.swift:485` usa `Unmanaged.passUnretained(self)` no callback de áudio. Se o objeto for desalocado durante o callback, é crash. Sem sincronização que garanta ciclo de vida. → `features/01-audio-capture.md`

2. **CRITICAL — Race condition em flush WAV**. `CoreAudioRecorder.swift:128-143` admite (em comentário) que `ExtAudioFileWrite` pode estar em andamento quando `ExtAudioFileDispose` é chamado em `stopRecording`. Pode corromper o header WAV (tamanho menor que payload). → `features/01-audio-capture.md`

3. ~~**CRITICAL — Force-unwrap em `AVAudioFormat`**~~ — **resolvido em PR #10**.

4. ~~**CRITICAL — Header WAV hardcoded em FluidAudio**~~ — **resolvido em PR #10**.

5. **HIGH — Parâmetros do usuário descartados silenciosamente em providers** (parcial). Soniox (`stt-rt-v4` hardcoded), Cartesia (`customVocabulary: []`) e Deepgram (`customVocabulary` não encaminhado) — **resolvidos em PR #11**. Mistral `language` e xAI `prompt`/`vocab` ficaram bloqueados em mudança upstream no LLMkit (ver backlog). → `features/03-cloud-transcription.md`, `features/04-streaming-transcription.md`

6. ~~**HIGH — Force-unwrap em `allPrompts.first!`**~~ — **resolvido em PR #10**.

7. **HIGH — WordReplacement quebrado para palavras com acento** — **resolvido em PR C** (`\b` + `useUnicodeWordBoundaries`). → `features/08-dictionary-vocabulary.md`

8. **HIGH — CGEvent sem verificação de retorno**. `CursorPaster.swift:120-138` faz `CGEvent.post` sem checar sucesso. Paste silencioso de falha quando o usuário não concedeu Accessibility ainda — bug recorrente reportado em issues. → `features/12-paste-clipboard-media.md`

9. **HIGH — Race condition em PowerMode**. `PowerModeConfig.swift:346` (`setActiveConfiguration`) sem lock + observers desbalanceados em `PowerModeSessionManager.swift:70-90`. → `features/09-power-mode.md`

## Falsos positivos reidentificados durante a remediação

A auditoria inicial superestimou algumas severidades. Após verificação:

- **`CustomPrompt.swift:130` String(format:) injection** — não procede. A format string é fixa em `AIPrompts.customPromptTemplate` (compilada no source). O valor do usuário entra como argumento de substituição `%@`, que NSString/CFString não re-interpretam como format codes. Tokenização ainda recomendada como melhoria de robustez (não de segurança).
- **`LocalCLIService.swift` shell injection** — não procede. Prompts viajam via env vars (`VOICEINK_*`) e os templates usam `"$VAR"` (aspas duplas); zsh não re-interpreta o conteúdo dessas variáveis. A única exploração possível é o usuário escrever um template `eval`-style, o que é o usuário se atacar.
- **`TranscriptionModel.swift` `let id = UUID()`** — não procede para uso runtime; persistência usa `name`, não `id`. Riscos residuais movidos para LOW (backup/restore).
- **Vários "parâmetros descartados" em xAI, Mistral, ElevenLabs** — análise revelou que parte é limitação upstream do LLMkit, parte é API que não suporta os parâmetros, parte foi erro de leitura da auditoria. Ver seção "Bloqueado por dependências externas" no backlog.

## Padrões transversais detectados

Não são bugs pontuais, são **classes de problema** que se repetem em vários lugares:

- **Force-unwrap em APIs do Apple que podem falhar**: `AVAudioFormat(...)!`, `try!`, `prompt!.utf8CString`, `takeRetainedValue()` sem nil-check. Cada um é um candidato a crash.
- **Strings ignoradas no caminho do provider**: o método recebe `language`/`prompt`/`customVocabulary` mas o client subjacente é chamado sem esses parâmetros. Vazamento de contrato silencioso.
- **Regex frágil em texto natural**: substring `.contains()` em URLs/window titles/modelos, lookarounds ASCII-only sobre texto unicode, regex sem cache compilado em loops.
- **Race conditions em singletons mutáveis**: `PowerModeConfig.setActiveConfiguration` sem lock, `AudioDeviceConfiguration` sem thread-safety, `MediaController.muteGeneration` sem atomic.
- **Observers desbalanceados**: `NotificationCenter.addObserver` sem `removeObserver` correspondente em vários managers — memory leak de observers stale.
- **Magic numbers sem rationale**: `chunkSize = 50_000_000`, thresholds (5 chars/s, 8s, 30% mais longo), timeouts (60s, 2s) — ninguém pode revisitar com confiança porque nada documenta a origem do número.
- **`try?` engolindo erros relevantes**: arquivos órfãos no disco, falhas de migration, status corrompido — tudo silencioso.
- **Hardcoded model names / version strings**: `"gpt-5"`, `"gpt-oss-120b"`, `"stt-rt-v4"`, `"standard"`. Quebram em renomes de upstream.

## Distribuição por severidade

| Severidade | Achados aproximados | Onde se concentram |
| --- | --- | --- |
| CRITICAL | ~10 | Audio engine, FluidAudio, Whisper, PowerMode, Prompts |
| HIGH | ~35 | Providers (cloud + streaming), AI Enhancement, Hotkeys, ScreenCapture, Persistence |
| MEDIUM | ~70 | Inconsistências entre providers, race conditions menores, validação fraca, regex frágil |
| LOW | ~30 | Naming, dívida cosmética, comentários desatualizados |

## A lacuna mais importante

**Zero testes automatizados no pipeline de áudio + transcrição.** Os bugs mais sérios encontrados (header WAV, normalização por chunk, regex destrutivo de tags, parâmetros descartados em providers) seriam todos detectados por uma suite mínima de testes de integração com fixtures de áudio reais cobrindo:

- WAV com header canônico vs com chunks extra (LIST, bext, JUNK)
- Sample rates variados (8k, 16k, 22.05k, 44.1k, 48k)
- Mono e stereo
- Durações de 1s, 30s, 5min
- Texto contendo `<tags>`, acentos, RTL, emojis
- Cada provider mockado retornando respostas curtas/longas/truncadas

A documentação em `99-testing-strategy.md` detalha o esqueleto recomendado.

## Recomendação de priorização

- **Agora** (antes da próxima release ao usuário): itens CRITICAL e os top 5 HIGH. Detalhes em `90-priority-backlog.md`.
- **Próximo ciclo**: HIGH restantes + setup de testes de integração para áudio/transcrição.
- **Depois**: MEDIUM agrupados por feature, refactor de duplicação entre providers, normalização de naming.
- **Quando sobrar tempo**: LOW.

Vale ressaltar: o produto está usável hoje. Após PR #10, #11 e a PR C, os achados CRITICAL restantes (race conditions no `CoreAudioRecorder`) são edge-cases que dependem de timing específico durante gravação — não são triviais de disparar em uso normal, mas existem e merecem fix antes da próxima release pública.

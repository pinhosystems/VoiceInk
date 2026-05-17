# Resumo Executivo

## Veredicto

VoiceInk tem **arquitetura razoável** (camadas claras, protocolos para abstração de providers, Swift moderno com async/await), mas **disciplina de implementação irregular**. A maior fragilidade do projeto não é nenhum módulo específico — é a **ausência total de cobertura de testes automatizados em pipelines críticos** (áudio, transcrição, enhancement). Isso explica por que bugs estruturais (header de WAV hardcoded, regex destrutivo, normalização per-chunk, etc.) chegaram à produção e só foram caçados empiricamente.

A app funciona, mas opera no limite da segurança: cada mudança de provider, cada update de SDK, e cada refactor pequeno corre risco real de regressão silenciosa.

## Top 10 riscos atuais

Ordem aproximada por impacto. Detalhes em `features/`.

1. **CRITICAL — Race condition em audio callback**. `CoreAudioRecorder.swift:485` usa `Unmanaged.passUnretained(self)` no callback de áudio. Se o objeto for desalocado durante o callback, é crash. Sem sincronização que garanta ciclo de vida. → `features/01-audio-capture.md`

2. **CRITICAL — Race condition em flush WAV**. `CoreAudioRecorder.swift:128-143` admite (em comentário) que `ExtAudioFileWrite` pode estar em andamento quando `ExtAudioFileDispose` é chamado em `stopRecording`. Pode corromper o header WAV (tamanho menor que payload). → `features/01-audio-capture.md`

3. **CRITICAL — Code injection via `String(format:)` em prompts do usuário**. `CustomPrompt.swift:130` faz `String(format: prompt, ...)` com prompt fornecido pelo usuário. Conteúdo com `%x`/`%s` causa crash ou leitura de memória adjacente. → `features/07-prompts-templates.md`

4. **CRITICAL — Force-unwrap em `AVAudioFormat`**. `WhisperTranscriptionService.swift:104` faz `AVAudioFormat(...)!` — pode crash se o áudio do usuário tiver canal/sample-rate fora do padrão. → `features/02-whisper-local.md`

5. **CRITICAL — Header WAV hardcoded em FluidAudio**. `FluidAudioTranscriptionService.swift:134-138` faz `stride(from: 44, ...)` assumindo header canônico — mesmo bug que já corrigimos no Whisper. WAVs com chunks LIST/bext serão lidos incorretamente. → `features/05-native-fluidaudio.md`

6. **HIGH — Parâmetros do usuário descartados silenciosamente em providers**. xAI, Mistral, ElevenLabs, Deepgram, Soniox, Cartesia: pelo menos um de `language`/`prompt`/`customVocabulary`/`model.name` não é encaminhado ao client. Configuração do usuário some sem aviso. → `features/03-cloud-transcription.md`, `features/04-streaming-transcription.md`

7. **HIGH — Force-unwrap em `allPrompts.first!`**. `AIEnhancementService.swift:257` — se a lista de prompts estiver vazia (estado migrado mal, primeira inicialização edge case), crash. → `features/06-ai-enhancement.md`

8. **HIGH — WordReplacement quebrado para palavras com acento**. `WordReplacementService.swift:42` usa lookarounds `(?<![a-zA-Z0-9])` que não consideram unicode. "café" não dispara o replace; falha silenciosa em português, espanhol, alemão, francês. → `features/08-dictionary-vocabulary.md`

9. **HIGH — Shell injection em LocalCLIService**. `LocalCLIService.swift:121-124` interpola `systemPrompt`/`userPrompt` direto em comando shell. Conteúdo com `$`, backticks ou aspas pode executar. → `features/06-ai-enhancement.md`

10. **HIGH — CGEvent sem verificação de retorno**. `CursorPaster.swift:120-138` faz `CGEvent.post` sem checar sucesso. Paste silencioso de falha quando o usuário não concedeu Accessibility ainda — bug recorrente reportado em issues. → `features/12-paste-clipboard-media.md`

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

Vale ressaltar: o produto está usável hoje e os bugs CRITICAL não são todos disparados em uso normal — vários precisam de edge case específico (audio device trocado durante gravação, prompt do usuário com `%s`, WAV não-canônico). Mas todos são **deterministicamente disparáveis** por quem souber, e três deles podem causar crash visível.

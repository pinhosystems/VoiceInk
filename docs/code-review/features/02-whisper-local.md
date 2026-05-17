# Feature 02 — Transcrição Whisper local

## Visão geral

Transcrição offline via `whisper.cpp` (LibWhisper bridge), com download/seleção de modelos GGML, suporte a CoreML encoder, VAD (Silero), warmup com amostra empacotada.

## Arquivos

- `VoiceInk/Transcription/Whisper/WhisperTranscriptionService.swift`
- `VoiceInk/Transcription/Whisper/WhisperModelManager.swift`
- `VoiceInk/Transcription/Whisper/WhisperModelProvider.swift`
- `VoiceInk/Transcription/Whisper/WhisperPrompt.swift`
- `VoiceInk/Transcription/Whisper/LibWhisper.swift`
- `VoiceInk/Transcription/Whisper/VADModelManager.swift`
- `VoiceInk/Transcription/Whisper/WhisperModelWarmupCoordinator.swift`
- `VoiceInk/Transcription/Engine/AudioFileProcessor.swift`

## Bugs

### CRITICAL

- `WhisperTranscriptionService.swift:104` — **Force-unwrap em `AVAudioFormat(...)!`**. Pode retornar `nil` para combinações inválidas de canal/sample rate. Áudios do usuário com configurações fora do esperado crashham o app.

### HIGH

- `WhisperTranscriptionService.swift:74` — `await modelProvider?.whisperContext !== whisperContext` quando `modelProvider` é `nil` sempre falha, e o contexto próprio criado em :42 nunca é liberado. Leak de contexto Whisper (megabytes a gigabytes).
- `WhisperModelManager.swift:280` — `model.coreMLEncoderURL = destination` muta struct enquanto download/setup pode estar em paralelo com `deleteModel()`. Sem sincronização.
- `LibWhisper.swift:50-57` — Force-unwrap em `prompt!.utf8CString` quando `setPrompt(nil)` foi chamado antes; pode usar prompt stale ou crashar.

### MEDIUM

- `AudioFileProcessor.swift:58` — **`chunkSize: AVAudioFrameCount = 50_000_000`**. Para sample rate 16 kHz isso são ~52 minutos de áudio — o "chunking" é efetivamente no-op em qualquer gravação real. Magic number sem rationale.
- `AudioFileProcessor.swift:98-100` — Dupla checagem de erro do `AVAudioConverter` (`if let error = error` seguido de `if status == .error`). A primeira só dispara quando o converter escreveu no error; código morto em parte dos casos.
- `WhisperTranscriptionService.swift:35` — `guard let modelURL = resolvedURL` sem distinção entre "modelo não encontrado" e "falha de carregamento"; erro genérico atrapalha diagnóstico.
- `WhisperModelManager.swift:128-137` — `ManagedAtomic` para flag de download, mas acesso ao `downloadProgress[progressKey]` (dicionário publicado) é não-sincronizado entre callback de progress e continuation.
- `WhisperModelManager.swift:156` — `try? FileManager.default.removeItem` engole erro; arquivos órfãos acumulam em disco.
- `WhisperPrompt.swift:84,97` — `UserDefaults.standard.synchronize()` deprecated; em crash imediato dados ainda podem se perder.
- `WhisperPrompt.swift:119` — `objectWillChange.send()` manual disparado mesmo quando o save subsequente falha; UI fica inconsistente com o estado real.
- `WhisperModelWarmupCoordinator.swift:45` — Tenta 3 paths sem logar qual encontrou; warmup silenciosamente falha se asset for movido entre versões.

### LOW

- `LibWhisper.swift:76` — bridge `vadModelPath as NSString` sem sincronização contra `setVADModelPath()`.
- `VADModelManager.swift:11` — `Bundle.main.url()` sem fallback; se o recurso `ggml-silero` não estiver empacotado, retorna `nil` em silêncio e VAD some sem aviso.
- `AudioFileProcessor.swift` — nome do arquivo (`AudioFileProcessor.swift`) diverge do nome do tipo (`AudioProcessor`).

## Melhorias (não-bugs)

- Tornar `WhisperTranscriptionService` injetável com o `AVAudioFormat` alvo (16 kHz mono Float32) construído uma vez e validado no init com erro tipado, em vez de force-unwrap por chamada.
- Adicionar checksum no download de modelos (`whisper.cpp` publica SHA256) antes de mover para destino final — atualmente um download corrompido é cacheado e usado.
- `chunkSize` em `AudioFileProcessor` precisa de rationale: definir constante nomeada (ex.: `chunkFrames = 16000 * 60` para 1 min de áudio a 16 kHz) e usar.
- Cache do `VadManager` entre chamadas de transcribe (ver `FluidAudio`); atualmente cria-se um por chamada.
- Trocar `UserDefaults.synchronize()` por aceitação da latência ou usar `NSUserDefaults` com observação assíncrona.

## Recomendação

- **Agora**: substituir o force-unwrap em `:104` por throw tipado; investigar e corrigir o leak de contexto em `:74`.
- **Em breve**: documentar `chunkSize` real, remover código morto do converter, sincronizar mutações de `coreMLEncoderURL`.
- **Depois**: checksum de modelos, cache de VAD, melhoria de logging em warmup.
- **Cobertura de testes**: fixtures de WAV com header não-canônico (LIST/bext/JUNK), sample rates exóticos, áudio vazio, áudio com canais > 2; assertir que `processAudioToSamples` não crasha e retorna shape esperado.

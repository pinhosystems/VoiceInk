# Feature 05 — Native Apple Speech + FluidAudio (Parakeet)

## Visão geral

Dois caminhos alternativos ao Whisper local: (a) `NativeAppleTranscriptionService` que usa `SpeechAnalyzer`/`SpeechTranscriber` (precisa de asset download por idioma) e (b) `FluidAudioTranscriptionService` que usa Parakeet on-device com VAD Silero.

## Arquivos

- `VoiceInk/Transcription/Native/NativeAppleTranscriptionService.swift`
- `VoiceInk/Transcription/FluidAudio/FluidAudioTranscriptionService.swift`
- `VoiceInk/Transcription/FluidAudio/FluidAudioModelManager.swift`

## Bugs

### CRITICAL

- `FluidAudioTranscriptionService.swift:134-138` — **`readAudioSamples()` hardcoda offset de 44 bytes** assumindo header WAV canônico. **Mesmo bug que foi corrigido em `WhisperTranscriptionService` no PR #9**, mas aqui ainda está. WAVs com chunks extras (LIST, bext, JUNK, fmt extended) corrompem a leitura — áudio sai desalinhado, transcrição vira nonsense.

### HIGH

- `FluidAudioTranscriptionService.swift:106` — `segments.flatMap { $0 }` assume segmentos não-vazios. Se VAD retorna array vazio (clipe muito silencioso), `speechAudio` fica como o original sem aviso; pode transcrever ruído como texto.

### MEDIUM

- `FluidAudioTranscriptionService.swift:94-100` — `VadManager` criado por transcribe, sem cache. Cada chamada aloca de novo; em transcrição em lote (drag-drop de várias gravações) é ramp-up de memória desnecessário.
- `FluidAudioModelManager.swift:67` — `defer { clearDownloadStatus(...) }` executa mesmo em erro de download, mas o arquivo parcial fica no cache; próxima tentativa parte de estado inconsistente.
- `FluidAudioModelManager.swift:98` — `try? FileManager.default.removeItem` engole erro de delete.

## Melhorias (não-bugs)

- Trocar `readAudioSamples` de FluidAudio pela mesma implementação `AVAudioFile` + `AVAudioConverter` que foi aplicada ao Whisper (`WhisperTranscriptionService.readAudioSamples` pós-PR #9). É copy-paste com adaptação mínima.
- Cachear `VadManager` na própria service (lazy, com cleanup quando o app for a background).
- Validar header WAV antes de processar (4 bytes `RIFF`, 4 bytes `WAVE`, achar chunk `fmt ` e `data` por busca, não offset fixo).
- `NativeAppleTranscriptionService` deveria expor estado de download de asset de forma observável para a UI (atualmente só erro tipado no fim).

## Recomendação

- **Agora**: substituir o `stride(from: 44, ...)` em `FluidAudioTranscriptionService:134-138` pela implementação `AVAudioFile`. Bug de produção real em qualquer WAV não-canônico.
- **Em breve**: cache de `VadManager`, cleanup de arquivos parciais no download de modelos.
- **Depois**: progresso observável para asset download do Native Apple.
- **Cobertura de testes**: fixture WAV com chunk LIST entre fmt e data → output do `readAudioSamples` deve bater com a versão `AVAudioFile`.

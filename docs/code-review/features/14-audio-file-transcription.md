# Feature 14 — Audio File Transcription (drag & drop)

## Visão geral

Permite arrastar arquivos de áudio para o app e transcrevê-los em lote. Fila `AudioFileQueueItem` em SwiftData, manager dedicado em `AudioFileTranscriptionManager`, service em `AudioFileTranscriptionService`.

## Arquivos

- `VoiceInk/Services/AudioFileTranscriptionManager.swift`
- `VoiceInk/Services/AudioFileTranscriptionService.swift`
- `VoiceInk/Services/SupportedMedia.swift`
- `VoiceInk/Models/AudioFileQueueItem.swift`
- `VoiceInk/Views/AudioTranscribeView.swift`
- `VoiceInk/Views/AudioFileRow.swift`
- `VoiceInk/Views/AudioPlayerView.swift`

## Bugs

### MEDIUM

- Reusa o `CloudTranscriptionService` e `WhisperTranscriptionService` — herda todos os bugs deles (header WAV, force-unwrap, parâmetros descartados).
- `AudioFileTranscriptionService` provavelmente roda em serial (verificar) — em lote grande de arquivos, sem concorrência limitada, pode ficar lento.
- `AudioFileQueueItem.swift:27` — `let id = UUID()` em property (mesmo padrão da feature 13).

### LOW

- `SupportedMedia.swift` — Lista hardcoded de extensões; conversão automática para WAV via `AVAssetExportSession` deveria estar documentada se acontece.

## Melhorias (não-bugs)

- Limite de concorrência configurável (default 2) para processar arquivos em paralelo respeitando rate limit do provider.
- Validar formato antes de submeter (alguns providers só aceitam WAV/MP3/M4A).
- Progresso por item observável na UI (provavelmente já existe; revisar consistência).
- Retry por item com backoff (não interromper a fila inteira em uma falha transient).

## Recomendação

- **Em breve**: garantir que a feature herde corretamente as correções aplicadas em transcription pipeline (parâmetros descartados, header WAV).
- **Depois**: concorrência configurável, retry por item.
- **Cobertura de testes**: fixture com 3 arquivos pequenos, mock do provider — verificar enfileiramento e progresso.

# Feature 17 — Session Metrics / Dashboard

## Visão geral

Para cada transcrição completada, registra um `SessionMetric` com palavras geradas, modelo usado, duração. Renderizado em `MetricsView` com painéis de performance por modelo.

## Arquivos

- `VoiceInk/Models/SessionMetric.swift`
- `VoiceInk/Services/SessionMetricRecorder.swift`
- `VoiceInk/Services/SessionMetricMigrationService.swift`
- `VoiceInk/Views/MetricsView.swift`
- `VoiceInk/Views/Metrics/*.swift`

## Bugs

### MEDIUM

- `SessionMetricRecorder.swift:31-32` — `WordCounter` inline sem validação; pode retornar 0 silenciosamente em strings com whitespace-only.
- `SessionMetricMigrationService.swift:17` — `!isRunning` sem lock (mencionado em feature 13).
- `SessionMetricMigrationService.swift:84` — Visibilidade do flag `isRunning = false` para observers não garantida.

### LOW

- `SessionMetricRecorder.swift:56` — Log com `privacy: .public` expõe UUID de transcription.

## Melhorias (não-bugs)

- Migration de dashboard com testes (faltam — qualquer mudança de schema é roleta).
- Agregação de métricas por janela móvel (últimos 7d, 30d) cacheada para evitar refetch.

## Recomendação

- **Depois**: lock em migration, métricas agregadas com cache.
- **Cobertura de testes**: WordCounter com edge cases (whitespace, emojis, números).

# Feature 13 — Histórico & Persistência (SwiftData)

## Visão geral

Toda transcrição é persistida via `@Model Transcription` em SwiftData. Histórico renderizado em `TranscriptionHistoryView`. Auto-cleanup opcional (`TranscriptionAutoCleanupService`). Migrations específicas para session metrics e streaming keys.

## Arquivos

- `VoiceInk/Models/Transcription.swift`
- `VoiceInk/Models/SessionMetric.swift`
- `VoiceInk/Models/AudioFileQueueItem.swift`
- `VoiceInk/Models/TranscriptionModel.swift`
- `VoiceInk/Models/TranscriptionModelRegistry.swift`
- `VoiceInk/Services/TranscriptionAutoCleanupService.swift`
- `VoiceInk/Services/SessionMetricMigrationService.swift`
- `VoiceInk/Services/LastTranscriptionService.swift`

## Bugs

### HIGH

- `LastTranscriptionService.swift:130` — Force-unwrap em `newTranscription.enhancedText!`. Se o enhancement não rodou (skip por tamanho mínimo) ou falhou, `enhancedText` é `nil` → crash.

### MEDIUM

- `Transcription.swift:27` — `transcriptionStatus: String?` em vez de `TranscriptionStatus` enum direto. Permite armazenar string inválida via mau decode.
- `Transcription.swift:58` — Construtor recebe `TranscriptionStatus` mas armazena `.rawValue` — round-trip de conversão indica que o modelo deveria armazenar o enum.
- `TranscriptionModel.swift:175-176` — Migration legada de API key no decode (`init(from:)`) sem validar sucesso do save no Keychain.
- `SessionMetricMigrationService.swift:17` — Check `!isRunning` sem sincronização; multiple app instances podem rodar migration concorrentemente.
- `SessionMetricMigrationService.swift:84` — Reassign de `isRunning = false` em closure sem garantia de visibility para observadores.
- `LastTranscriptionService.swift:71, 96` — `asyncAfter(deadline: .now() + 0.15)` cargo-cult; máquinas lentas podem precisar mais, rápidas desperdiçam latência.

### LOW

- `TranscriptionModel.swift:64,75,194,220`, `AudioFileQueueItem.swift:27`, `SessionMetric.swift:6-7` — `let id = UUID()` inline em properties. **Severidade reavaliada após investigação**: o ID é estável dentro de uma mesma sessão (Swift inicializa a property uma única vez na criação da instância, não a cada acesso), e o codebase persiste seleção de modelo por `name` (`TranscriptionModelManager:70-71, 85-95`), não por `id`. Único risco real: backups que armazenam `model.id` (`BackupTypes.swift:39`) ficam stale entre app launches porque `predefinedModels` recria os UUIDs. Fix correto seria UUID determinístico derivado do `name`.

## Melhorias (não-bugs)

- Trocar `let id = UUID()` em struct properties por `let id: UUID` no init explícito (compile-time vê o problema).
- Promover `transcriptionStatus` para `@Attribute` com `enum TranscriptionStatus: String, Codable` — SwiftData armazena rawValue mas a API exposta fica tipada.
- Migration de schema documentada num arquivo dedicado: cada `@Model` versionado com `VersionedSchema`, migrations explícitas com testes.
- Substituir `asyncAfter` cargo cult por sinal real do que se está esperando (ex.: observar `NotificationCenter.transcriptionCompleted`).

## Recomendação

- **Agora**: corrigir `let id = UUID()` em structs (HIGH com efeito real em coleções) e o force-unwrap em `LastTranscriptionService:130`.
- **Em breve**: tipagem do `transcriptionStatus`, sincronização de migration.
- **Depois**: VersionedSchema documentada, eliminação de delays mágicos.
- **Cobertura de testes**: migration tests com schemas v1 → v2 → v3 (precisa primeiro versionar).

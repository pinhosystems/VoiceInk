# Backlog Priorizado

> Lista única, ordenada por impacto e esforço. Para detalhe e referências (arquivo:linha), consultar os docs em `features/`.

## Agora (antes da próxima release pública)

Bloqueios para um shipping seguro. Cada item tem efeito visível ao usuário ou risco real de crash/perda de dados.

| # | Item | Arquivo principal | Feature |
| --- | --- | --- | --- |
| 1 | Corrigir flush WAV race condition (drain antes do dispose) | `CoreAudioRecorder.swift:128-143` | [01](./features/01-audio-capture.md) |
| 2 | Substituir `Unmanaged.passUnretained` por `passRetained` no audio callback | `CoreAudioRecorder.swift:485` | [01](./features/01-audio-capture.md) |
| 3 | Eliminar force-unwrap em `AVAudioFormat(...)!` | `WhisperTranscriptionService.swift:104` | [02](./features/02-whisper-local.md) |
| 4 | Reescrever `readAudioSamples` em FluidAudio com `AVAudioFile` (mesma fix do Whisper) | `FluidAudioTranscriptionService.swift:134-138` | [05](./features/05-native-fluidaudio.md) |
| 5 | Trocar `String(format:)` por substituição de token em prompts customizados | `CustomPrompt.swift:130` | [07](./features/07-prompts-templates.md) |
| 6 | Eliminar shell injection via stdin no LocalCLIService | `LocalCLIService.swift:121-124` | [06](./features/06-ai-enhancement.md) |
| 7 | Verificar `CGEvent.post` retorno + `AXIsProcessTrusted` antes de pastar | `CursorPaster.swift:120-138` | [12](./features/12-paste-clipboard-media.md) |
| 8 | Encaminhar `language`/`prompt`/`customVocabulary` em xAI, Mistral, ElevenLabs, Deepgram | múltiplos providers | [03](./features/03-cloud-transcription.md) |
| 9 | Eliminar `allPrompts.first!` com fallback hardcoded | `AIEnhancementService.swift:257` | [06](./features/06-ai-enhancement.md) |
| 10 | Trocar lookarounds ASCII por boundary unicode-aware no WordReplacementService | `WordReplacementService.swift:42` | [08](./features/08-dictionary-vocabulary.md) |
| 11 | Lock em `PowerModeConfig.setActiveConfiguration` + cleanup de observers em PowerModeSessionManager | `PowerModeConfig.swift:346`, `PowerModeSessionManager.swift:70-90` | [09](./features/09-power-mode.md) |
| 12 | Corrigir hardcoded `"stt-rt-v4"` em Soniox e `customVocabulary: []` em Cartesia | streaming providers | [04](./features/04-streaming-transcription.md) |

## Em breve (próximo ciclo, 1-2 sprints)

Bugs HIGH restantes + investimento estrutural que paga rápido.

| # | Item | Feature |
| --- | --- | --- |
| 14 | Setup de testes automatizados de áudio/transcrição com fixtures (ver [99-testing-strategy.md](./99-testing-strategy.md)) | cross-cutting |
| 15 | Refactor flush de streaming: cada provider decide quando seu fluxo terminou | [04](./features/04-streaming-transcription.md) |
| 16 | Cache de SelectedTextService por sessão | [06](./features/06-ai-enhancement.md) |
| 17 | Bounds check em `allPrompts[index]` no MiniRecorderShortcutManager | [10](./features/10-hotkeys-intents.md) |
| 18 | Match de URL via `URLComponents` (não substring) em PowerMode | [09](./features/09-power-mode.md) |
| 19 | Timeout em AppleScript do BrowserURLService | [09](./features/09-power-mode.md) |
| 20 | Detectar e avisar quando vocabulário é truncado (Deepgram) | [04](./features/04-streaming-transcription.md) |
| 21 | Cache de regex compiladas em `WordReplacementService` e `AIEnhancementOutputFilter` | [06](./features/06-ai-enhancement.md), [08](./features/08-dictionary-vocabulary.md) |
| 22 | Revalidação periódica de license activation | [15](./features/15-licensing.md) |
| 23 | `NSScreen.screens.first` em todos os pontos (eliminar `[0]`) | [19](./features/19-recorder-ui.md), [20](./features/20-notifications.md) |
| 24 | Substituir `print()` por `Logger` no BackupImporter | [16](./features/16-backup-import-export.md) |
| 25 | Lookup de PATH dinâmico (Homebrew) no LocalCLIService | [06](./features/06-ai-enhancement.md) |

## Depois (quando tocar a área)

MEDIUM e LOW agrupados — vão sendo resolvidos conforme cada área for revisitada.

- Centralizar `UserDefaultsKey<T>` num namespace tipado. Reduz typos em todo o app.
- Capability flags por `CloudProvider`/`StreamingProvider` (`supportsLanguage`, `truncatesVocabularyAt`, etc.).
- Padronizar `TranscriptionRequest` como struct único em vez de N args.
- `safeAreaInsets` para notch dimensions em vez de magic numbers.
- Filler words por idioma.
- Cache de `VadManager` em FluidAudio.
- Checksum de modelos Whisper no download.
- Versioned schema para SwiftData com migration tests.
- Queue de notificações com fade-in/out.
- Reset por seção em Settings.
- Dedup case-insensitive em vocab/replacements.
- Cleanup de listeners em `AudioDeviceManager` com sincronização.
- Tirar SwiftUI de dentro de `CustomPrompt.swift` (Models/).
- Componentização de `Views/Settings/`.
- Telemetria opt-in de taxa de erro por provider.

## Quando sobrar tempo

LOW prioridade — limpeza, naming, dívida cosmética.

- Renomear `AudioFileProcessor.swift` → `AudioProcessor.swift` (alinhar com tipo).
- Constantes nomeadas para chunk sizes (atualmente magic numbers).
- Remover dead code em `AnnouncementManager.swift:83`.
- Renomear log identifiers privados/públicos com critério (audit completo).
- Localização das Siri Phrases em `AppShortcuts`.

## Não fazer

Itens que não valem o investimento dado o contexto do projeto:

- "Endurecer" a obfuscação de licença. O app é GPL; sistema de license é gate de boa-fé. Investir em criptografia real é desperdício.
- Reescrever do zero o `StreamingTranscriptionService` antes de ter testes. Iterar é mais barato; refactor sem teste é como mover móveis no escuro.
- Adicionar `Co-Authored-By: Claude` nas mensagens de commit (preferência do mantenedor).

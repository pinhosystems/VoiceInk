# Backlog Priorizado

> Lista única, ordenada por impacto e esforço. Para detalhe e referências (arquivo:linha), consultar os docs em `features/`.

## Agora (antes da próxima release pública)

Bloqueios para um shipping seguro. Cada item tem efeito visível ao usuário ou risco real de crash/perda de dados.

Status: ✅ feito · 🟡 parcial · ❌ falso positivo verificado · ⬜ pendente.

| # | Status | Item | Arquivo principal | Feature |
| --- | --- | --- | --- | --- |
| 1 | ❌ | Flush WAV race condition — **verificado**: PR #7 já adicionou `AudioUnitUninitialize` como drain barrier (linhas 125-137), e `ExtAudioFileDispose` é documentado pela Apple como flush-on-close. Sem race real. | `CoreAudioRecorder.swift:125-145` | [01](./features/01-audio-capture.md) |
| 2 | ❌ | `Unmanaged.passUnretained` no callback — **verificado**: `deinit` chama `stopRecording` → `AudioUnitUninitialize` que faz drain síncrono de callbacks em vôo, garantindo que nenhum callback usa o ponteiro durante o teardown. Sem janela real de crash. | `CoreAudioRecorder.swift:485` | [01](./features/01-audio-capture.md) |
| 3 | ✅ | `AVAudioFormat(...)!` (PR #10) | `WhisperTranscriptionService.swift` | [02](./features/02-whisper-local.md) |
| 4 | ✅ | FluidAudio `readAudioSamples` via `AVAudioFile` (PR #10) | `FluidAudioTranscriptionService.swift` | [05](./features/05-native-fluidaudio.md) |
| 5 | ❌ | `String(format:)` injection — **verificado falso positivo** (PR #12 doc) | `CustomPrompt.swift:130` | [07](./features/07-prompts-templates.md) |
| 6 | ❌ | LocalCLI shell injection — **verificado falso positivo** (PR #12 doc) | `LocalCLIService.swift` | [06](./features/06-ai-enhancement.md) |
| 7 | ✅ | `AXIsProcessTrusted` + notificação visível (PR #13) | `CursorPaster.swift` | [12](./features/12-paste-clipboard-media.md) |
| 8 | 🟡 | Encaminhar `customVocabulary` em DeepgramProvider e CartesiaStreamingProvider; `model.name` em SonioxStreamingProvider (PR #11). xAI/Mistral/ElevenLabs: ver seção "Bloqueado por LLMkit" abaixo. | múltiplos providers | [03](./features/03-cloud-transcription.md) |
| 9 | ✅ | `allPrompts.first!` fallback (PR #10) | `AIEnhancementService.swift` | [06](./features/06-ai-enhancement.md) |
| 10 | ✅ | Boundary unicode-aware em WordReplacementService (PR #12) | `WordReplacementService.swift` | [08](./features/08-dictionary-vocabulary.md) |
| 11 | ✅ | `@MainActor` em `PowerModeManager` + investigação de observers (PR #13) | `PowerModeConfig.swift`, `PowerModeSessionManager.swift` | [09](./features/09-power-mode.md) |
| 12 | ✅ | Soniox `model.name` + Cartesia `customVocabulary` (PR #11) | streaming providers | [04](./features/04-streaming-transcription.md) |

**Lista "Agora" zerada de itens pendentes acionáveis.** Os falsos positivos verificados (#1, #2, #5, #6) estão documentados nos features/. Restam apenas itens upstream (LLMkit) listados na seção dedicada abaixo.

## Em breve (próximo ciclo, 1-2 sprints)

Bugs HIGH restantes + investimento estrutural que paga rápido.

| # | Status | Item | Feature |
| --- | --- | --- | --- |
| 14 | ⬜ | Setup de testes automatizados de áudio/transcrição com fixtures (ver [99-testing-strategy.md](./99-testing-strategy.md)) | cross-cutting |
| 15 | ⬜ | Refactor flush de streaming: cada provider decide quando seu fluxo terminou | [04](./features/04-streaming-transcription.md) |
| 16 | ⬜ | Cache de SelectedTextService por sessão | [06](./features/06-ai-enhancement.md) |
| 17 | ❌ | Bounds check em `allPrompts[index]` no MiniRecorderShortcutManager — **verificado**: o check já existe na linha 269 do arquivo atual (`if index < availablePrompts.count`). | [10](./features/10-hotkeys-intents.md) |
| 18 | ⬜ | Match de URL via `URLComponents` (não substring) em PowerMode | [09](./features/09-power-mode.md) |
| 19 | ✅ | Timeout de 3s em AppleScript do BrowserURLService (PR F) | [09](./features/09-power-mode.md) |
| 20 | ⬜ | Detectar e avisar quando vocabulário é truncado (Deepgram) | [04](./features/04-streaming-transcription.md) |
| 21 | ✅ | Cache de regex compiladas em `WordReplacementService` (per-process) e pré-compilação em `AIEnhancementOutputFilter` (PR F) | [06](./features/06-ai-enhancement.md), [08](./features/08-dictionary-vocabulary.md) |
| 22 | ⬜ | Revalidação periódica de license activation | [15](./features/15-licensing.md) |
| 23 | ✅ | `NSScreen.screens.first` em vez de `[0]` (NotificationManager, AnnouncementManager, DictionaryQuickAddPanel) (PR F) | [19](./features/19-recorder-ui.md), [20](./features/20-notifications.md) |
| 24 | ✅ | `print()` → `Logger` no BackupImporter (PR F) | [16](./features/16-backup-import-export.md) |
| 25 | ❌ | Lookup de PATH dinâmico no LocalCLIService — **verificado**: já implementado em `discoverPATHFromInteractiveLoginShell()` (linhas 188-254 do arquivo atual). | [06](./features/06-ai-enhancement.md) |

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

## Bloqueado por dependências externas (LLMkit)

A investigação durante a PR B revelou que alguns "parameter forwarding bugs" originalmente listados no item #8 são limitações do package `LLMkit` (vendor externo via SPM), não do VoiceInk. O cliente Swift do LLMkit precisa expor os parâmetros antes do provider poder repassá-los.

| Item | Status | O que falta |
| --- | --- | --- |
| `MistralProvider` enviar `language` ao client | bloqueado | `MistralTranscriptionClient.transcribe` não tem parâmetro `language` (a API Mistral suporta). Abrir PR no LLMkit. |
| `XAIProvider` enviar `prompt`/`customVocabulary` ao client | inviável upstream | API xAI STT (`POST /v1/stt`) não documenta suporte a esses parâmetros — `language`+`format` são os únicos. Provavelmente não há fix possível. |
| `ElevenLabsProvider` "não envia language" | inválido | Já envia. Auditoria estava errada na linha 52 do provider. |

Recomendação: abrir issue no repo do LLMkit pedindo `MistralTranscriptionClient.transcribe(... language: String? = nil ...)`; quando publicarem a versão, bumpar o pin do package aqui.

## Não fazer

Itens que não valem o investimento dado o contexto do projeto:

- "Endurecer" a obfuscação de licença. O app é GPL; sistema de license é gate de boa-fé. Investir em criptografia real é desperdício.
- Reescrever do zero o `StreamingTranscriptionService` antes de ter testes. Iterar é mais barato; refactor sem teste é como mover móveis no escuro.
- Adicionar `Co-Authored-By: Claude` nas mensagens de commit (preferência do mantenedor).

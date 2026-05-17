# Feature 12 — Cursor Paster / Clipboard / MediaController

## Visão geral

`CursorPaster` cola texto via `CGEvent` (Cmd+V) no app frontmost; salva e restaura pasteboard. `ClipboardManager` faz read de clipboard com bundle source. `MediaController` muta/desmuta áudio do sistema; `PlaybackController` pausa/retoma mídia.

## Arquivos

- `VoiceInk/CursorPaster.swift`
- `VoiceInk/ClipboardManager.swift`
- `VoiceInk/MediaController.swift`
- `VoiceInk/PlaybackController.swift`

## Bugs

### CRITICAL

- `CursorPaster.swift:120-138` — **`CGEvent.post(tap: .cghidEventTap)` sem verificar retorno**. Em macOS, Accessibility precisa estar concedido para HID events; sem permissão, `post` falha silenciosamente. Sintoma reportado em issues: "VoiceInk não cola após primeira instalação". O usuário pensa que está tudo certo (transcrição apareceu na UI), mas nada foi colado.

### MEDIUM

- `CursorPaster.swift:96` — `TISCopyCurrentKeyboardInputSource()` pode retornar `nil` em estados raros do sistema; `takeRetainedValue()` força unwrap implícito.
- `CursorPaster.swift:70-77` — `DispatchQueue.main.asyncAfter` para restaurar clipboard não tem context de cancellation; restore executa mesmo se o app encerrou ou se o usuário cancelou.
- `MediaController.swift:23-48` — `muteGeneration` não-atomic.
- `MediaController.swift:77-96` — `getDefaultOutputDevice` chamado em cada `isSystemAudioMuted` sem cache.

### LOW

- `ClipboardManager.swift:16` — Custom `NSPasteboard.PasteboardType("org.nspasteboard.source")` armazenando bundle ID: convenção de terceiros (nspasteboard.org), não é garantido sobreviver a managers de clipboard arbitrários.

## Melhorias (não-bugs)

- **Verificar Accessibility antes de cada paste**: usar `AXIsProcessTrusted()` e, se falso, abrir System Settings (`AXIsProcessTrustedWithOptions`) e mostrar notificação inequívoca em vez de colar silenciosamente para o vazio.
- Refatorar `CursorPaster.startPasteAtCursor` para retornar `Result<Void, PasteError>`; pipeline pode logar e notificar.
- Cache de `defaultOutputDevice` no `MediaController` com invalidação via `kAudioHardwarePropertyDefaultOutputDevice` listener.
- Tornar `restoreClipboard` cancelable via token; cancelado em `cleanupResources`.

## Recomendação

- **Agora**: checar retorno de `CGEvent.post` e validar `AXIsProcessTrusted` antes de pastar. Bug funcional visível em primeira execução pós-install — afeta first impression do produto.
- **Em breve**: tratamento robusto de input source; cancellation do restore de clipboard.
- **Depois**: cache de default output device.
- **Cobertura de testes**: difícil para CGEvent; smoke test manual documentado em checklist de release.

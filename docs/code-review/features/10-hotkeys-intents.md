# Feature 10 — Hotkeys & App Intents

## Visão geral

Hotkey global para abrir o recorder, configurável (`hotkeyMode1/2`), com detecção custom de fn-key e double-tap, middle-click, e atalhos para alternar entre prompts/modos. Integra com `AppIntents` para Siri Shortcuts.

## Arquivos

- `VoiceInk/HotkeyManager.swift`
- `VoiceInk/MiniRecorderShortcutManager.swift`
- `VoiceInk/AppIntents/AppShortcuts.swift`
- `VoiceInk/AppIntents/ToggleMiniRecorderIntent.swift`
- `VoiceInk/AppIntents/DismissMiniRecorderIntent.swift`

## Bugs

### HIGH

- `HotkeyManager.swift:281` — Captura `self` em closure mas acessa após retorno; race condition sutil entre setup e cleanup de monitoring.
- `MiniRecorderShortcutManager.swift:191-220` — Setup de 10 power mode handlers com `[weak self]` e índices fixos: se a coleção subjacente muda dinamicamente, calls com índices stale viram silent no-op.
- `MiniRecorderShortcutManager.swift:268` — `enhancementService.allPrompts[index]` sem bounds check; crash se prompts forem removidos entre binding e execução.

### MEDIUM

- `HotkeyManager.swift:72` — Array `middleClickMonitors: [Any?]` em vez de `[Any]`. Pattern frágil (linha 312 itera com unwrap desnecessário).
- `HotkeyManager.swift:363` — Captura `[pendingState, pendingTime]` em closure aninhado que também acessa `self.pendingFnKeyState`. Race se `fnDebounceTask` for cancelada antes da execução.
- `MiniRecorderShortcutManager.swift:58` — `Task { @MainActor in for await ... }` (visibilityTask) cancelado em :294, mas a subscrição `AsyncSequence` persiste — semântica de cancel não totalmente garantida pela API.

### LOW

- `HotkeyManager.swift:56-90` — 11 `@Published` properties com `didSet` salvando em `UserDefaults` — múltiplos writes síncronos sem coalescing.
- `AppShortcuts.swift:8-27` — Frases hardcoded sem localization keys; Siri não suporta em outros idiomas.

## Melhorias (não-bugs)

- Coalescer escrita de UserDefaults via `DispatchSourceTimer` (debounce 200 ms) — uma escrita por janela em vez de 11.
- Usar `KeyboardShortcuts.Name(rawValue:)` no init (uma vez) em vez de criar dinamicamente.
- Centralizar definição de power mode shortcuts em um único builder com bounds-check.
- App Intent phrases lidas de `Localizable.strings` (`LocalizedStringResource`).

## Recomendação

- **Agora**: bounds check em `allPrompts[index]` (causa crash real).
- **Em breve**: revisar capture semantics em `HotkeyManager`, eliminar race em `fnDebounceTask`.
- **Depois**: coalescing de UserDefaults, localization de phrases.
- **Cobertura de testes**: unit test para `HotkeyManager.detectFnKeyDoubleTap` com timestamps mockados.

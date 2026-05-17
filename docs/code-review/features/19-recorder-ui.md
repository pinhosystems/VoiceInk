# Feature 19 — Notch / Mini Recorder UI

## Visão geral

Mini-recorder flutuante mostrado em volta do notch (MacBook Pro) ou como floating window. Gerenciado por `RecorderUIManager`/`MiniRecorderShortcutManager`/`RecorderStateProvider`.

## Arquivos

- `VoiceInk/Views/Recorder/NotchRecorderView.swift`
- `VoiceInk/Views/Recorder/NotchRecorderPanel.swift`
- `VoiceInk/Views/Recorder/NotchShape.swift`
- `VoiceInk/Views/Recorder/RecorderStateProvider.swift`
- `VoiceInk/Views/Recorder/EnhancementPromptPopover.swift`
- `VoiceInk/Transcription/Engine/RecorderUIManager.swift`

## Bugs e dívida (geral)

- `RecorderUIManager` é `@MainActor`; OK.
- A view do notch precisa lidar com:
  - MacBook com notch (M1 Pro+).
  - MacBook sem notch.
  - Mac mini/Studio sem display interno.
  - Tela externa primária.
  - Display 4K vs Retina built-in.
- Lógica de posicionamento baseada em `NSScreen.main` (linha por linha pode estar usando `screens[0]`).

### MEDIUM

- `NotificationManager.swift:85` — `NSScreen.screens[0]` force-unwrap; crash potencial em hand-off rápido entre monitores (tela desconectada).
- A geometria do notch é codificada em pixels específicos; modelos novos podem ter notch diferente (15" vs 14" vs 16").

## Melhorias (não-bugs)

- Computar bounds do notch via `NSScreen.safeAreaInsets` (disponível em macOS 12+) em vez de pixels mágicos.
- Fallback gracioso para floating window quando não há notch detectável.
- Animação de transição entre estados (idle → starting → recording → transcribing → enhancing) com timing documentado.

## Recomendação

- **Em breve**: `safeAreaInsets` para notch dimensions; cleanup do `NSScreen.screens[0]`.
- **Depois**: testes manuais em MBP 14"/15"/16", iMac, Mac Studio, com displays externos.
- **Cobertura de testes**: snapshot testing de cada estado da pílula.

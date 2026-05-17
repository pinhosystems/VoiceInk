# Feature 18 — Settings UI

## Visão geral

Painéis SwiftUI para configurar AI Models, Enhancement, Hotkeys, Audio Input, Audio Cleanup, Dictionary, Custom Sound, Diagnostics. Várias views em `Views/Settings/`.

## Arquivos

- `VoiceInk/Views/Settings/*.swift`
- `VoiceInk/Views/ModelSettingsView.swift`
- `VoiceInk/Views/EnhancementSettingsView.swift`
- `VoiceInk/Views/Components/EnhancementSettingsPanel.swift`

## Bugs e dívida (geral)

- Padrão de gravação em `UserDefaults` via `@AppStorage` direto em cada view; sem centralização de keys, alto risco de typo.
- Mistura `@Published` em singletons com `@AppStorage` em views — duas fontes de verdade para o mesmo estado.
- Sem validação cruzada (ex.: timeout < 5 silenciosamente normalizado, mas a UI não comunica).
- Algumas views são monolíticas (>300 linhas); difícil de testar.

### MEDIUM

- Falta feedback de configuração inválida em runtime (ex.: API key incorreta só é descoberta ao usar).
- Nenhum mecanismo de "reset to defaults" por seção (só app-wide).

## Melhorias (não-bugs)

- Centralizar `UserDefaultsKey<T>` num namespace tipado:
  ```swift
  enum UDKey {
      static let transcriptionPrompt = UserDefaultsKey<String>("TranscriptionPrompt", default: "")
      static let appendTrailingSpace = UserDefaultsKey<Bool>("AppendTrailingSpace", default: false)
      // ...
  }
  ```
- Componentes reutilizáveis: `SettingsToggleRow`, `SettingsTextFieldRow`, `SettingsPickerRow`. Reduzem ruído.
- Health check ativo: ao salvar API key, fazer ping de validação; em caso de falha, marcar visualmente.
- Reset por seção via menu contextual.

## Recomendação

- **Depois**: refactor incremental conforme tocar cada painel. Centralizar UD keys é o ROI mais alto.
- **Cobertura de testes**: snapshot testing dos painéis (SnapshotTesting library) para detectar regressão visual.

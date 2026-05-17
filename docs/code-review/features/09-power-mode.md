# Feature 09 — Power Mode (perfis contextuais)

## Visão geral

Perfis configuráveis que ativam combinações de prompt + modelo de transcrição + AI Enhancement quando o usuário está em determinada app, URL, ou perfil padrão. Detecção via `ActiveWindowService` (frontmost app) + `BrowserURLService` (AppleScript para Chrome/Safari/Arc/Brave/Edge/Firefox/Zen).

## Arquivos

- `VoiceInk/PowerMode/PowerModeSessionManager.swift`
- `VoiceInk/PowerMode/PowerModeStateProvider.swift`
- `VoiceInk/PowerMode/PowerModeValidator.swift`
- `VoiceInk/PowerMode/PowerModeConfig.swift`
- `VoiceInk/PowerMode/PowerModeShortcutManager.swift`
- `VoiceInk/PowerMode/ActiveWindowService.swift`
- `VoiceInk/PowerMode/BrowserURLService.swift`

## Bugs

### CRITICAL

- `PowerModeConfig.swift:346` — **`setActiveConfiguration` sem sincronização**. Escritas concorrentes em `activeConfiguration` (state) e `UserDefaults` podem causar inconsistência entre o que a UI mostra e o que o pipeline usa. Disparável com hotkeys rápidas ou hand-off entre apps.

### HIGH

- `PowerModeSessionManager.swift:70` — `NotificationCenter.default.addObserver(self, ...)` sem `removeObserver` correspondente em `endSession` (linha 90). Se `beginSession` rodar várias vezes sem encerrar, leak de observadores e callbacks duplicados.
- `BrowserURLService.swift:131` — `output.lowercased().contains("error")` para detectar falha de AppleScript: frágil (output legítimo pode conter "error" como parte do texto da página, e mensagem de erro localizada não bate).
- `PowerModeConfig.swift:236-251` — `cleanedURL.contains(configURL)` faz match por substring: `"amazon.com"` casa `"amazon.com.br"` falsamente. Usuário configura regra para um e atinge o outro.

### MEDIUM

- `PowerModeSessionManager.swift:42-76` — Flag `isApplyingPowerModeConfig` lida/escrita sem sincronização entre `updateSessionSnapshot` e `applyConfiguration`.
- `PowerModeSessionManager.swift:148` — `allAvailableModels.first(where:)` linear a cada aplicação de config; OK com 10 modelos, ruim se cresce.
- `PowerModeShortcutManager.swift:33-42` — Itera `registeredPowerModeIds` e modifica durante iteração; pode estar funcional hoje, mas inseguro contra concorrência.
- `PowerModeValidator.swift:40-91` — Validação de URL duplicada por string equality crua, sem normalização (`http://` vs `https://`, trailing slash, www).
- `PowerModeValidator.swift:60-73` — Não deduplica `appConfigs` por `bundleIdentifier` dentro de uma config; usuário pode adicionar duplicatas.
- `ActiveWindowService.swift:22-68` — `applyConfiguration` sem mutual exclusion: chamadas concorrentes podem aplicar configs sobrepostas.
- `ActiveWindowService.swift:44-51` — Catch genérico, perde a distinção entre `scriptNotFound`/`executionFailed`; debug do usuário fica impossível.
- `BrowserURLService.swift:110-121` — `Process` sem timeout. AppleScript travado → hang indefinido sem cancellation.
- `BrowserURLService.swift:66-68` — `allCases` hardcoded omite `.firefox` e `.zen`; discrepância com o enum.

### LOW

- `PowerModeShortcutManager.swift:40` — `KeyboardShortcuts.Name` dinâmico criado a cada call.

## Melhorias (não-bugs)

- Wrap `PowerModeConfig` mutável em `actor` ou guardar com `OSAllocatedUnfairLock`. Singleton mutável de feature crítica precisa disso.
- Match de URL via `URLComponents` + comparação por host (igual + sufixo opcional `.tld`) — não substring.
- `Process.terminationHandler` + timer de 3 s em `BrowserURLService.fetchURL` para matar AppleScript travado.
- `applyConfiguration` em `ActiveWindowService` com fila serial: ignora chamadas em curso (debounce de 100 ms).
- Validador deveria normalizar URL (lowercase host, strip `www.`, strip trailing `/`) antes de comparar.

## Recomendação

- **Agora**: lock em `setActiveConfiguration` (CRITICAL com efeito real em uso intenso); cleanup de observers em `PowerModeSessionManager`.
- **Em breve**: matching de URL robusto; timeout em AppleScript.
- **Depois**: deduplicação de configs, validação normalizada.
- **Cobertura de testes**: matcher de URL com fixtures cobrindo subdomain, port, query, fragment.

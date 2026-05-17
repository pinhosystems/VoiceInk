# Feature 20 — Notificações & Announcements

## Visão geral

`NotificationManager` mostra mini-toasts in-app (não NSUserNotification do sistema). `AnnouncementsService` busca anúncios remotos (release notes, urgent fixes) de URL fixa.

## Arquivos

- `VoiceInk/Notifications/NotificationManager.swift`
- `VoiceInk/Notifications/AppNotificationView.swift`
- `VoiceInk/Notifications/AppNotifications.swift`
- `VoiceInk/Notifications/AnnouncementManager.swift`
- `VoiceInk/Notifications/AnnouncementView.swift`
- `VoiceInk/Services/AnnouncementsService.swift`

## Bugs

### HIGH

- `NotificationManager.swift:20-26` — Trigger de dismiss não cancela o timer da notificação anterior. Duas `showNotification` rápidas → primeira é dismissed com o delay errado.
- `AnnouncementsService.swift:26, 30` — `Timer` não invalidado em deinit. Singleton, não morre, mas é leak padrão.

### MEDIUM

- `NotificationManager.swift:85` — `NSScreen.screens[0]` force-unwrap; tela desconectada → crash.
- `AnnouncementsService.swift:42-65` — URLSession task em `[weak self]`: se `self` deallocar antes do completion, fetch silencioso vai pro lixo sem UI feedback.
- `AnnouncementsService.swift:13` — URL hardcoded sem fallback.
- `AnnouncementManager.swift:83` — `y = max(a, a)` (args idênticos); dead code retornando sempre o mesmo valor.

## Melhorias (não-bugs)

- Queue de notificações: cada `showNotification` enqueue; render serial com fade-in/out.
- Validar `NSScreen.screens.first` (não `[0]`) em todo o app.
- Backoff + retry no fetch de announcements em vez de single-shot.
- Esquema versionado de announcements (atual: `Codable` direto).

## Recomendação

- **Em breve**: trocar `screens[0]` por `.first`; cancelar timer anterior no `NotificationManager`.
- **Depois**: queue de notificações; retry de announcements.
- **Cobertura de testes**: unit test de queue com mock de timer.

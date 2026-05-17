# Feature 15 — Licenciamento & Trial

## Visão geral

Sistema de licença com trial de 7 dias e ativação via Polar (`PolarService`). Estado mantido em `LicenseManager` + `LicenseViewModel`. Activation ID guardado em Keychain. "Obfuscação" via `Obfuscator` para device-bound hashes.

## Arquivos

- `VoiceInk/Models/LicenseViewModel.swift`
- `VoiceInk/Services/LicenseManager.swift`
- `VoiceInk/Services/PolarService.swift`
- `VoiceInk/Services/Obfuscator.swift`

## Bugs

### CRITICAL

- `LicenseViewModel.swift:13` — **`licenseState = .trial(daysRemaining: 7)`** default hardcoded. Em build `LOCAL_BUILD` (flag de compile) omite validação. **Trivialmente burlável** por renomeio de bundle, build flag, ou fork da app.
- `PolarService.swift:6` — **`organizationId` hardcoded** ("6f3d781d-a630-4435-9dba-058486f2d936"). Facilita engenharia reversa e geração de chaves falsas.
- `PolarService.swift:7` — `baseURL` hardcoded sem fallback. Mudança de servidor torna o app inoperável em ativação.

### HIGH

- `LicenseViewModel.swift:50-54` — Se há `activationId` armazenado, considera licenciado **sem revalidar**. Activation cancelado upstream continua "ativo" indefinidamente.
- `Obfuscator.swift:8-12` — **"Obfuscação" via Base64 com salt**. Trivialmente reversível. Não é criptografia, e o salt é device serial / UUID em UserDefaults legível.

### MEDIUM

- `LicenseViewModel.swift:68` — Cálculo de dias do trial sem timezone awareness; usuário pode manipular relógio do sistema.
- `LicenseManager.swift:34-39` — `Date.timeIntervalSince1970` serializado como `String` no Keychain; parse errors são frágeis, sem versionamento de schema.
- `PolarService.swift:76, 122, 155` — Logs com `privacy: .public` sobre resposta do servidor podem vazar activation ID e status.

## Melhorias (não-bugs)

- **Honestidade do modelo**: dado que VoiceInk é GPL, o licenciamento é mais "porteiro educado" que segurança real. Em vez de pretender criptografia, documente o gate como "trial de boa-fé" e foque na simplicidade.
- Revalidação periódica: a cada 24 h, verificar com Polar se o `activationId` ainda é válido (kill switch para refunds, etc.).
- Sair de `LOCAL_BUILD` toggle para `Bundle.main.bundleIdentifier` allowlist explícita (com fallback razoável).
- `privacy: .private` em todos os logs que tocam activation ID / status detalhado.
- Mover `organizationId` para `Config.xcconfig` (não público no source, ainda inspecionável no binary).

## Recomendação

- **Agora**: alinhar expectativas. Se a intenção é monetizar fork como hardpaid, este sistema não cobre. Se a intenção é "porteiro educado", documentar e parar de gastar tempo em obfuscação fake. Dado o licenciamento GPL, o caminho realista é o segundo.
- **Em breve**: revalidação periódica, mover org ID para xcconfig.
- **Depois**: cleanup de logs de licença.
- **Cobertura de testes**: licença expirada, license downgrade entre versions.

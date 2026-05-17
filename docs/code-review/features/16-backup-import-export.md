# Feature 16 — Backup / Import / Export

## Visão geral

Exportar e importar configurações: custom prompts, vocabulário, replacements, custom cloud models, power mode configs. `BackupImporter` orquestra; `ImportExportService` faz IO; `VoiceInkCSVExportService` exporta histórico em CSV.

## Arquivos

- `VoiceInk/Services/BackupImporter.swift`
- `VoiceInk/Services/BackupTypes.swift`
- `VoiceInk/Services/ImportExportService.swift`
- `VoiceInk/Services/VoiceInkCSVExportService.swift`

## Bugs

### HIGH

- `BackupImporter.swift:48, 70, 195, ...` — **`print()`** em `@MainActor` em vários pontos. Não-auditável, e pode logar conteúdo sensível do backup (incluindo prompts do usuário com dados privados).
- `ImportExportService.swift:218, 333` — `DispatchQueue.main.async` aninhado em contexto já `@MainActor`; comportamento OK, mas indica que o autor não tinha clareza do contexto.

### MEDIUM

- `BackupImporter.swift:46` — `predefined + imported` sem dedup; reimport multiplica prompts.
- `BackupImporter.swift:282` — API key vazia em custom model importado é aceita silenciosamente.
- `ImportExportService.swift:262` — Version mismatch só alerta, prossegue import; incompatibilidade vira corrupção silenciosa.
- `BackupTypes.swift:47` — `apiKey: nil` em backup: se o user exporta com key, ela é discartada no export sem aviso. Ao importar, o user descobre que precisa reconfigurar tudo.
- `VoiceInkCSVExportService.swift:30-31` — `escapeCSVString()` não escapa newlines em campos quoted; transcrição com `\n` quebra o CSV no Excel/Numbers.
- `VoiceInkCSVExportService.swift:38` — `ISO8601Format()` pode falhar; sem try-catch.

### LOW

- `ImportExportService.swift:146-154` — `try?` em fetch engole erros; dados ausentes não são reportados.

## Melhorias (não-bugs)

- Trocar `print()` por `Logger` com `privacy: .private` no backup importer.
- Dedup por nome + UUID antes de inserir prompts/configs.
- Política explícita sobre API keys no backup: exportar criptografado com senha do usuário (idealmente) ou documentar claramente que keys não são exportadas (e exigir reconfiguração).
- CSV: usar lib (`SwiftCSV` ou similar) em vez de escape manual.
- Migration de schema do backup versionada com migrators automáticos.

## Recomendação

- **Em breve**: substituir `print` por Logger; corrigir CSV escape.
- **Depois**: dedup, versionamento explícito do backup format, política de API keys.
- **Cobertura de testes**: round-trip (export → import) em todos os tipos com fixtures contendo edge cases.

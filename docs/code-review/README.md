# VoiceInk — Auditoria de Código por Feature

> Auditoria de qualidade orientada a feature, com priorização por criticidade.
> Data da revisão: 2026-05-16.
> Branch base: `fix/transcription-pipeline-hardening` (após PRs #7, #8, #9).

## Como ler esta documentação

Esta auditoria está organizada por **feature** (não por arquivo), porque o impacto de cada bug e cada item de dívida técnica é melhor avaliado em termos do que o usuário enxerga e do que o time de manutenção precisa proteger.

- [`00-executive-summary.md`](./00-executive-summary.md) — resumo dos achados, top-10 riscos.
- [`01-architecture.md`](./01-architecture.md) — leitura arquitetural cross-cutting.
- [`features/`](./features/) — um documento por feature, com bugs e melhorias.
- [`90-priority-backlog.md`](./90-priority-backlog.md) — backlog priorizado (Agora / Em breve / Depois).
- [`99-testing-strategy.md`](./99-testing-strategy.md) — recomendação de estratégia de testes (a maior lacuna do projeto).

## Rubrica de criticidade

| Nível | Significado | Janela de ação |
| --- | --- | --- |
| **CRITICAL** | Crash, perda de dados, vazamento de segredo, regressão visível ao usuário em fluxo principal | **Agora** — antes da próxima release |
| **HIGH** | Bug funcional confirmado, race condition, falha silenciosa que degrada o produto | **Em breve** — próximo ciclo |
| **MEDIUM** | Antipattern com risco real, inconsistência entre providers, dívida que atrapalha evolução | **Depois** — quando tocar a área |
| **LOW** | Limpeza, naming, refactor cosmético, comentário enganoso | **Quando sobrar tempo** |

## Inventário de features auditadas

1. [Captura de áudio (Recorder, Core Audio)](./features/01-audio-capture.md)
2. [Transcrição Whisper local](./features/02-whisper-local.md)
3. [Transcrição cloud (batch)](./features/03-cloud-transcription.md)
4. [Transcrição em streaming](./features/04-streaming-transcription.md)
5. [Native Apple Speech & FluidAudio](./features/05-native-fluidaudio.md)
6. [AI Enhancement (pós-processamento)](./features/06-ai-enhancement.md)
7. [System Prompts & Templates](./features/07-prompts-templates.md)
8. [Dicionário / Vocabulário / Word Replacement](./features/08-dictionary-vocabulary.md)
9. [Power Mode (perfis contextuais)](./features/09-power-mode.md)
10. [Hotkeys & App Intents](./features/10-hotkeys-intents.md)
11. [Screen Capture + OCR (contexto)](./features/11-screen-capture-ocr.md)
12. [Cursor Paster / Clipboard / MediaController](./features/12-paste-clipboard-media.md)
13. [Histórico & Persistência (SwiftData)](./features/13-history-persistence.md)
14. [Audio File Transcription (drag & drop)](./features/14-audio-file-transcription.md)
15. [Licenciamento & Trial](./features/15-licensing.md)
16. [Backup / Import / Export](./features/16-backup-import-export.md)
17. [Session Metrics / Dashboard](./features/17-session-metrics.md)
18. [Settings UI](./features/18-settings-ui.md)
19. [Notch / Mini Recorder UI](./features/19-recorder-ui.md)
20. [Notificações & Announcements](./features/20-notifications.md)

## Metodologia

- Leitura direta dos arquivos Swift do app (221 arquivos auditados).
- Cruzamento com bugs já vistos em produção e corrigidos nas PRs #7–#9.
- Agentes paralelos varreram clusters de arquivos para achados pontuais com linha-referência.
- Foco em **risco para o usuário** e **risco para o time de manutenção**, não em estilo subjetivo.

## O que esta auditoria NÃO faz

- Não substitui revisão humana caso-a-caso antes de cada fix.
- Não cobre performance medida (precisa profiling em hardware real).
- Não cobre segurança ofensiva profunda (precisa pentest específico).
- Não cobre acessibilidade da UI (VoiceOver, contraste, dynamic type) — recomendado para auditoria separada.

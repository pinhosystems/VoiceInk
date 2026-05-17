# Feature 11 — Screen Capture + OCR (contexto)

## Visão geral

Quando habilitado, captura screenshot da tela principal via `ScreenCaptureKit` no início da gravação e roda OCR via Vision (`VNRecognizeTextRequest`). Texto resultante é injetado no contexto do AI Enhancement.

## Arquivos

- `VoiceInk/Services/ScreenCaptureService.swift`

## Bugs

### HIGH

- `ScreenCaptureService.swift:51-52` — `configuration.width / height` multiplicado por 2 sem comentário. Magic number (provavelmente para Retina), mas em displays 6K+ pode overflow em allocations downstream do Vision.
- `ScreenCaptureService.swift:83` — `Task.detached(priority: .userInitiated)` sem timeout: OCR em imagem grande pode rodar segundos; sem cancellation se o usuário começou e cancelou rapidamente.

### MEDIUM

- `ScreenCaptureService.swift:63-70` — `@Published lastCapturedText` acessado concorrentemente sem proteção; se múltiplas capturas simultâneas (não devia acontecer, mas possível em edge case), valores intercalam.

## Melhorias (não-bugs)

- Documentar o `*2` em comment com referência ao DPI da display.
- Timeout configurável de OCR (default 3 s) com cancellation se ultrapassado.
- Reduzir imagem a 1280×720 antes de OCR para reduzir tempo e memória em telas grandes (Vision lida com isso bem).
- Considerar opção de OCR só na janela frontmost (mais relevante que tela inteira) — usar `ScreenCaptureKit` filter por `SCWindow`.

## Recomendação

- **Em breve**: timeout no OCR, downscale antes do Vision.
- **Depois**: opção de captura por janela.
- **Cobertura de testes**: pouco automatizável sem hardware; smoke test com imagem fixture passada direto ao recognizer.

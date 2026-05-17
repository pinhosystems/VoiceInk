# Estratégia de Testes — Recomendação

## Por que isto é a maior alavanca

Quase todos os bugs CRITICAL e HIGH detectados nesta auditoria — header WAV hardcoded, force-unwrap em `AVAudioFormat`, regex destrutivo de tags, parâmetros descartados em providers, normalização per-chunk — seriam **interceptados em CI** por uma suite mínima de testes de integração. O projeto roda hoje em "confiança empírica" (rodar, perceber bug, corrigir, esperar não regressar). Cada bug listado aqui sobreviveu vários releases.

Custo de implementação: dias, não semanas. ROI: imenso.

## Pirâmide proposta

```
                  Manual smoke (release checklist)
              ▲   — paste em apps específicas, OCR
           ───┼───
            E2E (poucos, golden path)
              — gravar 30s → transcrever → enhance → paste
        ─────┴──────
         Integration (foco aqui)
           — pipeline com fixtures de áudio reais,
             providers mockados, asserções fortes
       ─────────┴──────────
        Unit (filtros, regex, format)
          — TranscriptionOutputFilter, WhisperTextFormatter,
            WordReplacement, PromptDetection, WordCounter
```

## Fase 1 — Setup (1 dia)

- Adicionar `VoiceInkTests` target (já é padrão Xcode).
- Configurar `swift-testing` (macOS 15+) ou XCTest.
- Pasta `Tests/Fixtures/Audio/` versionada (Git LFS se necessário; arquivos pequenos cabem em git normal):
  - `sample_16k_mono_canonical.wav` (header RIFF padrão)
  - `sample_16k_mono_with_list_chunk.wav`
  - `sample_44k_stereo.wav`
  - `sample_48k_stereo.m4a`
  - `silence_5s.wav`
  - `short_1s.wav`
  - `long_5min.wav` (gerado, voz sintetizada)
  - `multilanguage.wav` (PT-BR + EN)

## Fase 2 — Unit tests fáceis (1 dia)

Sem dependências externas; rodam em &lt;1s.

- `TranscriptionOutputFilter` — assert que `<TAG>conteúdo</TAG>` não é removido (regressão da PR #9).
- `WhisperTextFormatter` — capitalização, espaçamento, pontuação.
- `WordReplacementService` — fixtures com palavras acentuadas, RTL, emojis.
- `WordCounter` — whitespace, emojis, números.
- `PromptDetectionService` — strings com trigger words em posições variadas, emojis adjacentes.
- `FillerWordManager` — preservação de palavras legítimas que contenham filler como substring.
- `Obfuscator` — round-trip.

## Fase 3 — Integration: pipeline de áudio (2 dias)

O core do investimento. Mock dos providers via protocolo (já existe `CloudProvider`); assert sobre `processAudioToSamples` e `readAudioSamples`.

```swift
@Test func audioFileProcessor_handlesNonCanonicalWavHeader() async throws {
    let url = Bundle.testBundle.url(forResource: "sample_16k_mono_with_list_chunk", withExtension: "wav")!
    let samples = try await AudioProcessor().processAudioToSamples(url)
    #expect(samples.count > 0)
    // Comparar com versão de referência produzida por sox/ffmpeg
}

@Test func whisperTranscriptionService_does_not_crash_on_unusual_format() async throws {
    let url = Bundle.testBundle.url(forResource: "sample_48k_stereo", withExtension: "m4a")!
    // Deve não-throw force-unwrap, mesmo se transcribe falhar
    _ = try? await WhisperTranscriptionService(...).transcribe(audioURL: url, model: stubModel)
}
```

Cobre os bugs:
- Header WAV em FluidAudio.
- `AVAudioFormat!`.
- Per-chunk normalization (assert que samples adjacentes não tem descontinuidade > threshold).

## Fase 4 — Integration: providers cloud/streaming (2 dias)

Cada provider tem um mock `LLMkit.Client`. Assert que `language`, `prompt`, `customVocabulary`, `model.name` recebidos são passados ao mock client.

```swift
@Test func xaiProvider_forwards_language_to_client() async throws {
    let client = MockXAIClient()
    let provider = XAIProvider(client: client)
    _ = try await provider.transcribe(audioData: .empty, fileName: "a.wav", apiKey: "k", model: "grok", language: "pt-BR", prompt: "test", customVocabulary: ["foo"], resourceTimeout: 60)
    #expect(client.lastCall?.language == "pt-BR")
    #expect(client.lastCall?.prompt == "test")
}
```

Cobre os bugs:
- Parâmetros descartados em xAI, Mistral, ElevenLabs, Deepgram, Soniox, Cartesia.
- Hardcoded `"stt-rt-v4"`.

## Fase 5 — Snapshot tests de prompts (1 dia, opcional)

Para AIPrompts e PromptTemplates. Cada template renderizado com input fixture é comparado a golden master em disco. Mudanças no template forçam revisão explícita do diff.

## Fase 6 — Smoke test de release (checklist humano)

Documento `docs/release-checklist.md` (não existe ainda — vale criar) com:

- [ ] Build + install local.
- [ ] `tccutil reset Accessibility` + `tccutil reset ScreenCapture`.
- [ ] Conceder permissões na primeira execução.
- [ ] Gravar 10 s com Whisper local.
- [ ] Gravar 10 s com xAI streaming.
- [ ] Gravar 10 s com Deepgram batch.
- [ ] Gravar 10 s com `customVocabulary` configurado e dizer um termo dele.
- [ ] Pastar em Slack, Notes, Cursor, Terminal.
- [ ] AI Enhancement habilitado: ver que output não tem placeholder vazio.
- [ ] Power Mode ativando em browser com URL específica.
- [ ] Histórico mostra todas as gravações.

## Custo total estimado

| Fase | Esforço | Bugs interceptados |
| --- | --- | --- |
| 1 | 1 dia | — (infra) |
| 2 | 1 dia | 8+ unit-level |
| 3 | 2 dias | 5 CRITICAL/HIGH no áudio |
| 4 | 2 dias | 6 HIGH em providers |
| 5 | 1 dia | regressão de prompts |
| 6 | 0.5 dia (recorrente) | UX issues primeiras |

**~7.5 dias de engenharia** para uma rede de segurança que evita a próxima rodada de bugs equivalente aos das PRs #7-#9.

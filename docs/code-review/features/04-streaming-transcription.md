# Feature 04 — Transcrição em streaming

## Visão geral

WebSocket-based streaming via `LLMkit` para xAI, Deepgram, Assembly, Speechmatics, Cartesia, Soniox, ElevenLabs, Mistral, FluidAudio. Áudio enviado em chunks durante a gravação, eventos `partial`/`committed` recebidos e reconciliados, com fallback para batch via `StreamingTranscriptionSession.isSuspiciouslyShort`.

## Arquivos

- `VoiceInk/Transcription/Streaming/StreamingTranscriptionService.swift`
- `VoiceInk/Transcription/Streaming/StreamingTranscriptionProvider.swift`
- `VoiceInk/Transcription/Streaming/*StreamingProvider.swift` (10 arquivos)
- `VoiceInk/Transcription/Streaming/WordAgreementEngine.swift`
- `VoiceInk/Transcription/Engine/TranscriptionSession.swift`

## Bugs

### HIGH

- `SonioxStreamingProvider.swift:39` — **`"stt-rt-v4"` hardcoded ignora `model.name`** recebido como parâmetro. Configuração do usuário descartada.
- `SpeechmaticsStreamingProvider.swift:39` — `model.name.contains("standard")` faz substring matching para decidir tipo de modelo. Frágil: muda o nome upstream e quebra.
- `DeepgramStreamingProvider.swift:107` — `Array(unique.prefix(50))` corta vocabulário customizado em 50 termos sem avisar; usuário com 200 termos perde 150.
- Streaming hardcoded sem encaminhar `language` em vários providers (mesmo padrão da feature 03).

### MEDIUM

- `XAIStreamingProvider.swift:7` — `private let client` em escopo de instância; sem clareza se múltiplas instâncias podem compartilhar conexões. Ausência de thread-safety documentada.
- `AssemblyAIStreamingProvider.swift:114` — Vocabulário não é truncado (diferente de Deepgram); **inconsistência entre providers** — um silenciosamente trunca, outro não. Comportamento imprevisível.
- `CartesiaStreamingProvider.swift:36` — `customVocabulary: []` hardcoded vazio; feature de vocabulário simplesmente não funciona para Cartesia.
- `FluidAudioStreamingProvider.swift:107-108` — `Task.sleep` em loop sem timeout global; servidor inerte trava recursos indefinidamente.
- `WordAgreementEngine.swift:157-158` — confidence média sobre array vazio (`isEmpty` é checado, mas o cálculo subsequente pode dividir por zero em paths futuros se o invariante quebrar).
- `StreamingTranscriptionService.swift` (cluster) — Estado acumulado de 4 iterações (`commitSentAt`, `lastPartialText`, `partialsAreCumulative`, `streamTerminated`, `resolveFinalText`). Funciona, mas a abstração é leaky — comportamento específico do xAI vazou para o serviço genérico.
- `TranscriptionSession.swift:132-138` — Heurística de "suspiciously short" tem thresholds (`>=8s`, `<5 chars/s`) sem rationale escrito; difícil reajustar com confiança.

### LOW

- `StreamingTranscriptionProvider.swift:29` — Mensagem de erro genérica "Not connected" sem identificar o provider.
- Duplicação de código de deduplicação de vocabulário entre `DeepgramStreamingProvider` e `FluidAudioStreamingProvider` (mesma lógica copy-paste).
- `AssemblyAIStreamingProvider.swift:40` — Chave `"TranscriptionPrompt"` hardcoded inline.

## Melhorias (não-bugs)

- **Inverter responsabilidade do flush**: cada `StreamingTranscriptionProvider` deveria decidir quando seu fluxo "terminou de receber" e expor isso via API tipada. O serviço genérico fica burro (`waitForFinalText()` e usa o que veio). Isso elimina a Rube Goldberg de `resolveFinalText`/`partialsAreCumulative`/`streamTerminated`.
- Capability per provider: `truncatesVocabularyAt: Int?`, `requiresCommitEvent: Bool`, `partialsAreCumulative: Bool`. Move o conhecimento do quirk para o provider, não para o serviço.
- Para o xAI: dado o histórico de truncar a transcrição final, considerar marcar streaming como "best-effort" e sempre cair para batch se `chars/s` cair abaixo do esperado (já existe, mas com threshold conservador). Alternativa: desabilitar streaming para xAI por padrão.
- Backoff exponencial em reconexão de WebSocket por provider; atualmente é all-or-nothing.

## Recomendação

- **Agora**: corrigir o `"stt-rt-v4"` hardcoded em Soniox e o `customVocabulary: []` em Cartesia — são features advertidas que não funcionam.
- **Em breve**: refactor da decisão de flush (delegar ao provider); adicionar warning quando o vocabulário for truncado.
- **Depois**: capability flags por provider, eliminação da duplicação.
- **Cobertura de testes**: simulador de WebSocket por provider com fixtures de eventos (partial/committed em ordens variadas, socket close cedo, EOS atrasado) — assertir que o `resolveFinalText` final é correto.

# Feature 03 — Transcrição cloud (batch)

## Visão geral

Upload do arquivo de áudio (multipart streaming, pós-PR #9) para um de ~10 providers cloud (xAI, Groq, Mistral, Cartesia, Soniox, Gemini, Assembly, Speechmatics, ElevenLabs, Deepgram, OpenAI-compatible custom). Roteia via `CloudProviderRegistry` e `LLMkit`.

## Arquivos

- `VoiceInk/Transcription/Cloud/CloudTranscriptionService.swift`
- `VoiceInk/Transcription/Cloud/OpenAICompatibleTranscriptionService.swift`
- `VoiceInk/Transcription/Cloud/CloudProvider.swift`
- `VoiceInk/Transcription/Cloud/*Provider.swift` (10 arquivos)
- `VoiceInk/Transcription/Cloud/CustomCloudModelManager.swift`

## Bugs

### HIGH

- `XAIProvider.swift:30-31` — **`language` e `prompt` recebidos como parâmetros mas não encaminhados** ao `XAIClient.transcribe()`. Configuração do usuário perdida silenciosamente.
- `MistralProvider.swift:31` — **`language`, `prompt` e `customVocabulary` recebidos mas não encaminhados** ao client. Mesma classe de bug.
- `ElevenLabsProvider.swift:52` — `language` recebido mas não encaminhado.
- `DeepgramProvider.swift:45` — `fileName` e `customVocabulary` ignorados na chamada ao client; vocabulário customizado nunca aplicado.
- `CustomCloudModelManager.swift:27` — `APIKeyManager.shared.deleteCustomModelAPIKey()` chamado sem verificar retorno; falhas silenciosas deixam keys órfãs no Keychain.
- `TranscriptionModel.swift:144` — `CustomCloudModel.apiKey` lê Keychain em property sem `throws`; retorna `""` silenciosamente quando o Keychain falha, mascarando o problema (pode parecer "API key inválida" do lado do servidor).

### MEDIUM

- `CloudProvider.swift:29-31` — Default da extension retorna `unsupportedProvider`, mas não força providers a declarar capability flags (`supportsLanguage`, `supportsCustomVocabulary`, etc.). Resultado: parâmetros são silenciosamente ignorados sem warning de compile-time.
- `GeminiProvider.swift:54-60` — `fileName` passado mas não usado pelo client; contrato incompleto.
- `GroqProvider.swift:26` — URL `"https://api.groq.com/openai"` hardcoded; sem fallback nem ping de health.
- `CustomCloudModelManager.swift:89` — Validação de duplicação de nomes não exclui o UUID do modelo sendo editado; impede o usuário de salvar mudanças no próprio modelo.
- `TranscriptionModel.swift:175-176` — Migration legada de API key do JSON para Keychain durante decode sem validar sucesso do save.
- `OpenAICompatibleTranscriptionService.swift:26-27` — `timeoutIntervalForRequest = 60` hardcoded enquanto `timeoutIntervalForResource` respeita configuração. Usuário pode configurar 5 min de timeout total e bater no 60 s do request individual sem saber.

### LOW

- Hardcoded chave `"TranscriptionPrompt"` espalhada em múltiplos arquivos; centralizar em `UserDefaultsKey`.
- `OpenAICompatibleTranscriptionService.swift:51-53` — Decode falha cai em `noTranscriptionReturned`, perdendo o payload original do servidor (útil para diagnosticar respostas inesperadas).

## Melhorias (não-bugs)

- **Pacto de contrato**: incluir em `CloudProvider` propriedades `supportsLanguage`, `supportsCustomVocabulary`, `supportsTranscriptionPrompt`. Ao receber um parâmetro não suportado, logar `warning` em vez de descartar silenciosamente.
- Padronizar `fileName`, `language`, `prompt`, `customVocabulary` como parte de um struct `TranscriptionRequest` único em vez de N argumentos posicionais. Reduz a chance do bug "esqueci de passar X".
- Adicionar telemetria opcional para taxa de retry e taxa de falha por provider, ajudando o usuário a saber qual está degradado.
- Adicionar `Accept: application/json` no header de todos os providers OpenAI-compatible (vários servidores se comportam diferente sem isso).
- Tornar `Content-Type: audio/wav` configurável; `OpenAICompatibleTranscriptionService.swift:97` hardcoda — não aceita upload de MP3/M4A direto.

## Recomendação

- **Agora**: corrigir os 4 bugs HIGH de parâmetro descartado (xAI/Mistral/ElevenLabs/Deepgram). Cada um é uma feature do usuário que parece funcionar mas não funciona.
- **Em breve**: padronizar contrato `TranscriptionRequest`; introduzir validação de capabilities por provider.
- **Depois**: telemetria, cleanup de URLs hardcoded.
- **Cobertura de testes**: para cada provider, mock do client confirmando que `language`, `prompt`, `customVocabulary`, `fileName` recebidos são repassados.

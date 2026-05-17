# Visão Arquitetural Cross-Cutting

## Camadas

```
┌──────────────────────────────────────────────────────────────┐
│ SwiftUI Views  (Views/, Notifications/)                       │
├──────────────────────────────────────────────────────────────┤
│ Coordinators   (VoiceInkEngine, TranscriptionPipeline,        │
│                 RecorderUIManager, PowerModeSessionManager)   │
├──────────────────────────────────────────────────────────────┤
│ Domain Services                                                │
│  ├── Transcription/  (Engine, Cloud, Streaming, Whisper,      │
│  │                    FluidAudio, Native, Processing)         │
│  ├── AIEnhancement/  (AIService, AIEnhancementService,        │
│  │                    LocalCLI, OutputFilter)                 │
│  ├── PowerMode/      (Validator, SessionManager,              │
│  │                    ActiveWindowService, BrowserURLService) │
│  └── ScreenCapture, Selected Text, MediaController, etc.      │
├──────────────────────────────────────────────────────────────┤
│ Persistence    (SwiftData models, BackupImporter,             │
│                 Keychain, UserDefaults)                       │
├──────────────────────────────────────────────────────────────┤
│ Platform       (AVFoundation, CoreAudio, ScreenCaptureKit,    │
│                 Vision, Carbon Hotkeys, Accessibility API)    │
└──────────────────────────────────────────────────────────────┘
```

## Pontos fortes da arquitetura

- **Protocolos de abstração para multi-provider**: `TranscriptionService`, `CloudProvider`, `StreamingTranscriptionProvider`, `TranscriptionSession`. Permitem adicionar provider novo sem mexer no core.
- **Pipeline isolada em coordinator**: `TranscriptionPipeline` concentra o fluxo pós-recording. Fácil entender o caminho do dado.
- **Serviço de registro com criação tardia**: `TranscriptionServiceRegistry` cria sessions sob demanda, com cleanup explícito.
- **DispatchQueue dedicada para hardware**: `audioSetupQueue` evita travar main thread em setup de Core Audio.
- **Logging consistente**: todo módulo usa `Logger(subsystem: "com.prakashjoshipax.voiceink", category: "...")`. Facilita debugging de produção.
- **SwiftData para persistência local**: `@Model Transcription`, `@Model SessionMetric`, etc. Codegen de queries via macros, menos boilerplate.
- **Swift concurrency**: `async/await`, `Task`, `MainActor` isolation usados de forma idiomática na maior parte.

## Pontos fracos da arquitetura

### 1. Abstração leaky no streaming

`LLMkit.StreamingTranscriptionEvent` finge uniformizar 10+ providers de streaming que se comportam de formas radicalmente diferentes no flush final (commit, EOS, socket close). Resultado: `StreamingTranscriptionService` acumulou estado (`commitSentAt`, `lastPartialText`, `partialsAreCumulative`, `streamTerminated`, `resolveFinalText`) só pra contornar comportamentos provider-específicos. A correção arquitetural é mover decisão de flush pra dentro de cada `StreamingTranscriptionProvider` — não tratar isso como "evento normalizado".

### 2. Singletons globais sem disciplina

Vários componentes-chave são singletons (`PowerModeManager.shared`, `MediaController.shared`, `PlaybackController.shared`, `AudioDeviceManager.shared`, `WordReplacementService.shared`, `NotificationManager.shared`, `SoundManager.shared`, `APIKeyManager.shared`, `LicenseManager.shared`...). Singletons não são em si um problema, mas aqui:

- Vários têm estado mutável (`@Published`) sem proteção contra concorrência.
- Acoplam código em pontos imprevisíveis (a `TranscriptionPipeline` toca `PowerModeManager`, `SoundManager`, `WordReplacementService`, `NotificationManager`...).
- Bloqueiam unit testing (não dá pra injetar mocks).

### 3. Persistência espalhada por três caminhos

- **SwiftData**: `Transcription`, `SessionMetric`, `VocabularyWord`, `WordReplacement`, `AudioFileQueueItem`.
- **UserDefaults**: dezenas de chaves diferentes (`"SelectedLanguage"`, `"TranscriptionPrompt"`, `"AppendTrailingSpace"`, `"SkipShortEnhancement"`, `"ShortEnhancementWordThreshold"`, ...). Sem centralização das keys nem types.
- **Keychain**: API keys por provider, com migração custom (`StreamingKeysMigration`).
- **JSON em UserDefaults**: `customPrompts` via `JSONEncoder` em didSet.

Cada uma com seu próprio padrão de leitura/escrita, sem camada unificada. Mudança de schema é caso a caso e arriscada.

### 4. UI e modelo misturados

`CustomPrompt.swift` (Models/) contém views SwiftUI nas linhas 237–256. Isso quebra separation of concerns — modelos deveriam ser puros e renderizar deveria ficar em Views. Pequeno, mas é um precedente perigoso (próximas pessoas vão imitar).

### 5. Falta de gates de qualidade no repo

Não há (visível):
- Suite de testes XCTest/SwiftTesting rodando em CI.
- Linter (SwiftLint, SwiftFormat) configurado.
- Verificação de force-unwrap como erro de build.
- Pre-commit checando typos (revelaria "Your are" em prompts).
- Pipeline de regressão semântica em prompts (saber se mudar o template degrada saída).

## Convenções implícitas (úteis pra manter)

- **`os.Logger` com subsystem fixo `"com.prakashjoshipax.voiceink"`** e category por arquivo/feature. Manter.
- **Erros tipados por feature**: `CloudTranscriptionError`, `AudioProcessingError`, `VoiceInkEngineError`, etc. com `LocalizedError`. Manter.
- **DI via init em coordinators principais**: `VoiceInkEngine.init(modelContext:whisperModelManager:transcriptionModelManager:enhancementService:)`. Manter; expandir para singletons gradualmente.
- **`@MainActor` em coordinators de UI/orquestração**: Manter.

## Próximos passos arquiteturais sugeridos (em ordem)

1. **Introduzir camada de testes** com fixtures de áudio (não precisa de hardware, basta arquivos versionados).
2. **Centralizar `UserDefaults` keys** num namespace tipado (struct com `static let` de `UserDefaultsKey<T>`). Reduz typos e facilita migration.
3. **Atomic + locks em singletons mutáveis** (PowerModeManager, MediaController). Pequeno custo, grande blindagem.
4. **Inverter responsabilidade do flush no streaming**: cada `StreamingTranscriptionProvider` decide quando "terminou de receber"; serviço genérico só repassa.
5. **Linter + pre-commit hook** para impedir reincidência das classes de bug detectadas.

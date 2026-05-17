# Feature 01 — Captura de áudio (Recorder + Core Audio)

## Visão geral

Captura via Core Audio Unit, grava em WAV `Int16` mono 16 kHz no Application Support, expõe medidor em tempo real, troca de device em runtime, mute/restore de áudio do sistema, integração com player de mídia (pausa/retoma).

## Arquivos

- `VoiceInk/Recorder.swift`
- `VoiceInk/CoreAudioRecorder.swift`
- `VoiceInk/Services/AudioDeviceManager.swift`
- `VoiceInk/Services/AudioDeviceConfiguration.swift`
- `VoiceInk/PlaybackController.swift`
- `VoiceInk/MediaController.swift`

## Bugs

### CRITICAL

- `CoreAudioRecorder.swift:485` — **`Unmanaged.passUnretained(self)` em callback de audio thread**. Sem sincronização que garanta o ciclo de vida da instância. Se `CoreAudioRecorder` for desalocado enquanto o callback C ainda está rodando, é crash determinístico em produção. **Disparável** se a parada da gravação coincidir com chunks em vôo.
- `CoreAudioRecorder.swift:128-143` — **Race condition no flush do WAV**. O próprio comentário admite que `ExtAudioFileWrite` (audio thread) pode estar mid-write quando `stopRecording` chama `ExtAudioFileDispose`. `AudioUnitUninitialize()` bloqueia, mas não há garantia de flush dos buffers internos do `ExtAudioFileRef`. Pode corromper o header WAV (tamanho menor que o payload real) — sintoma compatível com o bug histórico de "arquivo cortado".

### HIGH

- `CoreAudioRecorder.swift:780` — Cópia de `outputBuffer` via `Data(bytes:, count:)` sem sincronização com possíveis realocações em `switchDevice()`. Janela curta, mas existe.
- `CoreAudioRecorder.swift:268-282` — `switchDevice()` realoca `renderBuffer` e `conversionBuffer` enquanto o callback pode estar usando. A parada da AudioUnit é o único sincronizador; se houver um pacote em vôo na fila do driver, leitura pós-dealloc.
- `AudioDeviceManager.swift:391` — Listener C do CoreAudio usa `Unmanaged.fromOpaque(...).takeUnretainedValue()`. `deinit` (linha 477) remove o listener mas não sincroniza com callback em execução. Em apps long-running isso raramente dispara, mas é a mesma classe do bug 1.

### MEDIUM

- `Recorder.swift:167` — `onAudioChunk = nil` atribuído sem sincronização; `CoreAudioRecorder` acessa essa closure em audio thread (linha 778) sem lock.
- `Recorder.swift:246-249` — Acesso a `smoothedAverage`/`smoothedPeak` protegido por `NSLock`, mas a leitura de `recorder.averagePower`/`peakPower` (linha 219-220) é não-sincronizada com o callback que os atualiza.
- `CoreAudioRecorder.swift:595-596` — `guard isRecording` sem sincronização — pode mudar entre check e uso.
- `AudioDeviceManager.swift:305-312` — `getCurrentDevice()` com fallback lê `prioritizedDevices` e `availableDevices` sem lock.
- `PlaybackController.swift:107-118` — `resumeTask` reatribuído sem cancelar o anterior. Chamadas rápidas em sequência agendam múltiplas tasks paralelas, geram flutter de play/pause.
- `MediaController.swift:23-48` — `muteGeneration` lido/escrito sem `atomic`/`OSAllocatedUnfairLock`. Em condições de mute/unmute fast, leituras stale.
- `MediaController.swift:77-96` — `getDefaultOutputDevice` chamado em cada `isSystemAudioMuted` sem cache; syscalls repetidas.
- `PlaybackController.swift:38-40` — closure `onTrackInfoReceived` com `[weak self]` lendo `self?.isMediaPlaying` — se `self` for nil, update é descartado silenciosamente.

### LOW

- `AudioDeviceConfiguration.swift:41` — `createDeviceChangeObserver` não remove observador anterior, possível leak se chamado múltiplas vezes.
- `PlaybackController.swift:126-139` — `sendMediaPlayPauseKey` cria `NSEvent` sem checar permissão de event tap em ambiente sandboxed.

## Melhorias (não-bugs)

- Promover `Recorder` e `CoreAudioRecorder` para usar `OSAllocatedUnfairLock` em todos os pontos de troca entre main thread e audio thread.
- Substituir `Unmanaged.passUnretained` por `passRetained` + `takeRetainedValue` no callback final, com retain explícito durante toda a vida do recorder.
- Introduzir `flush()` síncrono em `CoreAudioRecorder` antes de `Dispose`: drain de packets pendentes + `ExtAudioFileWriteSync(nil, 0, nil)` + leitura de `kExtAudioFileProperty_FileMaxPacketSize` antes de fechar.
- Extrair o medidor (`audioMeter`) para um struct value-type lido via `@Published` em snapshot, removendo a necessidade de lock manual.
- Centralizar normalização dB→0..1 em helper testável (atualmente inline em `updateAudioMeter`).

## Recomendação

- **Agora**: corrigir o flush do WAV (`CoreAudioRecorder.swift:128-143`) e o lifecycle do callback (`:485`). Ambos são CRITICAL com efeito visível ao usuário.
- **Em breve**: cobrir realocação de buffers em `switchDevice` com sincronização explícita; auditar todas as travessias main↔audio.
- **Depois**: refactor do medidor e cleanup de listeners.
- **Cobertura de testes**: fixtures de gravação de 1s, 30s, 5min em sample rates 8k/16k/44.1k/48k, mono/stereo, com asserções sobre `chunks==RIFF header size == file size` no WAV resultante.

<div align="center">
  <img src="VoiceInk/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="180" height="180" />
  <h1>Open Voice</h1>
  <p>Local-first voice-to-text for macOS with multilingual LLM enhancement</p>

  [![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
  ![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-brightgreen)
</div>

---

Open Voice is a local-first dictation app for macOS. Speech goes through your choice of on-device or cloud STT, the LLM enhancement layer cleans and reformats the transcript for the active context, and a Power Mode picks the right model + prompt automatically based on the app or website you're using.

The fork is free, does not sell licenses, and does not talk to any commerce backend. It exists to explore multilingual dictation (pt-BR first), a richer multi-provider pipeline, and an opinionated set of Power Mode presets.

## Features

- **Local + cloud STT** — Whisper.cpp, Parakeet (FluidAudio), and Apple's native speech engine on-device. xAI Grok, Groq, Deepgram, ElevenLabs, OpenAI, Soniox, Gemini, and Mistral via direct API for low-latency cloud transcription.
- **LLM enhancement** — Anthropic, OpenAI, OpenRouter, Ollama, custom OpenAI-compatible endpoints, and arbitrary Local CLI agents. Multi-instance support per provider.
- **Power Mode profiles** — Auto-apply STT model + language + LLM prompt + auto-send key based on the active app or open URL. Per-config hotkeys for manual activation. Six starter presets ship: AI Coding Agent, Dev Environment, Messaging, Email, Writing, AI Chat.
- **Native system prompts** — Default, Assistant, Task Prompt (speech → clean brief for Claude Code / Cursor / Copilot Chat), Rewrite, Email, Chat, Code Comment.
- **Multilingual tech-term salvage** — When the STT language is non-English, an `<AUDIO_LANGUAGE>` block plus a per-locale salvage table tells the LLM how to recover canonical English spellings for tech jargon mistranscribed phonetically (commit → comêti / cómit, push → puxe / puch, ...). Curated tables for pt-* and es-*, generic fallback for every other non-English locale.
- **Multilingual pipeline** — All locale-specific behavior (input normalization, vocabulary biasing, fillers, Whisper seeds, LLM format rules) routes through a `LocalePack` lookup. Curated pack for pt-BR (`BrazilianPortuguesePack`: CPF/CNPJ/CEP/phone identifiers, R$, dd/mm/aaaa, "duas horas e meia" → "2h30", Brazilian fillers, BR vocabulary, BR chat-abbreviation expansions). Conservative generic pack for other pt-* variants (`PortuguesePack`: covers pt-PT, pt-AO, pt-MZ, plain "pt" — output-only). Synthesised `GenericLocalePack` for every other non-English locale. Adding a new curated language is a single new file under `VoiceInk/Locale/Packs/`.
- **Per-history retry flow** — Re-analyze the LLM step in place, or re-transcribe from the saved audio with a different model / profile.
- **Troubleshooting log per transcription** — Every outbound API call (STT, LLM, Local CLI) records its request + response in a per-record fixture with configurable retention. Bearer tokens are never written by construction.

## Requirements

- macOS 14.4 or later
- Xcode 16+ (only when building)

## Build from source

This is a personal fork; binaries are not published. Build locally with the included `Makefile`:

```bash
make setup-signing    # one-time: provisions a stable self-signed cert in your login keychain
make install-local    # builds, signs, installs to /Applications, launches
```

The first `install-local` after `setup-signing` prompts for Accessibility, Screen Recording, and Microphone permissions. Subsequent rebuilds preserve those grants because the Designated Requirement stays constant across builds.

For full build details (whisper.cpp framework, Swift packages, signing internals), see [BUILDING.md](BUILDING.md).

## Issues

Report bugs or request features in the fork's [issue tracker](https://github.com/pinhosystems/VoiceInk/issues).

## Acknowledgments

**Core technology**
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) — High-performance inference of OpenAI's Whisper model
- [FluidAudio](https://github.com/FluidInference/FluidAudio) — Parakeet model implementation

**Swift dependencies**
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — User-customizable keyboard shortcuts
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) — Launch-at-login support
- [MediaRemoteAdapter](https://github.com/ejbills/mediaremote-adapter) — Media playback control during recording
- [Zip](https://github.com/marmelroy/Zip) — File compression utilities
- [SelectedTextKit](https://github.com/tisfeng/SelectedTextKit) — Selected-text capture on macOS
- [Swift Atomics](https://github.com/apple/swift-atomics) — Low-level atomic primitives

## License

Licensed under [GPL v3](LICENSE). Modifications and additions in this fork are documented in the git commit history.

---

<div align="center">
  <sub>
    Open Voice is a personal fork of <a href="https://github.com/Beingpax/VoiceInk">Beingpax/VoiceInk</a> by Prakash Joshi Pax. The upstream project is the load-bearing foundation this fork builds on — full credit for the original architecture, design judgment, and feature set belongs to its author. If this fork is useful to you and you can spare it, please consider supporting the original at <a href="https://tryvoiceink.com">tryvoiceink.com</a>.
  </sub>
</div>

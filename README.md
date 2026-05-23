<div align="center">
  <img src="VoiceInk/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="180" height="180" />
  <h1>Open Voice</h1>
  <p>Local-first voice-to-text for macOS with multilingual LLM enhancement</p>

  [![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
  ![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-brightgreen)
</div>

---

## About this project

Open Voice is a personal fork of **[Beingpax/VoiceInk](https://github.com/Beingpax/VoiceInk)** by Prakash Joshi Pax — the upstream project ships an excellent local-first dictation app for macOS, and the entire foundation of Open Voice is its work: the SwiftUI surface, the Whisper integration, the global hotkey pipeline, the Power Mode concept, the system-instruction wrapper, and the AI-enhancement plumbing. Open Voice cannot exist without it, and every meaningful feature listed below stands on that base.

This fork is local-first, free, does not sell licenses, and does not talk to any commerce backend. It exists to explore multilingual dictation (pt-BR first), a richer multi-provider STT/LLM pipeline, and a more opinionated Power Mode preset library. If you want a polished, supported product, install the original from [tryvoiceink.com](https://tryvoiceink.com) — that release ships features that aren't part of this fork (signed binaries, automatic updates, customer support, paid tier).

![Open Voice screenshot](docs/screenshot.png)

## Features

Inherited from upstream and refined in this fork:

- **Local + cloud STT** — Whisper.cpp, Parakeet (FluidAudio), and Apple's native speech engine on-device. xAI Grok, Groq, Deepgram, ElevenLabs, OpenAI, Soniox, Gemini, and Mistral via direct API for low-latency cloud transcription.
- **LLM enhancement** — Anthropic, OpenAI, OpenRouter, Ollama, custom OpenAI-compatible endpoints, and arbitrary Local CLI agents. Multi-instance support per provider.
- **Power Mode profiles** — Auto-apply STT model + language + LLM prompt + auto-send key based on the active app or open URL. Per-config hotkeys for manual activation.
- **Per-history retry flow** — Re-analyze the LLM step in place, or re-transcribe from the saved audio with a different model / profile.

Added in this fork:

- **Six Power Mode presets** ship out of the box — AI Coding Agent, Dev Environment, Messaging, Email, Writing, AI Chat — each pre-binding apps, URLs, prompts, and behavior for a common dictation context.
- **Native system prompts** — Default, Assistant, Task Prompt (speech → clean brief for Claude Code / Cursor / Copilot Chat), Rewrite, Email, Chat, Code Comment.
- **Multilingual tech-term salvage** — When the STT language is non-English, an `<AUDIO_LANGUAGE>` block plus a per-locale salvage table tells the LLM how to recover canonical English spellings for tech jargon mistranscribed phonetically (commit → comêti / cómit, push → puxe / puch, ...). Curated tables for pt-* and es-*, generic fallback for every other non-English locale.
- **Brazilian Portuguese pipeline** — Native vocabulary biasing for pt-BR speakers (CPF, CNPJ, CEP, R$, dd/mm/aaaa formatting), Brazilian post-processing, and pt-specific salvage tables.
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

## License & attribution

Licensed under [GPL v3](LICENSE).

**Open Voice is derived from [Beingpax/VoiceInk](https://github.com/Beingpax/VoiceInk) by Prakash Joshi Pax.** That project is the load-bearing dependency — not a side reference — and full credit for the underlying architecture, the original feature set, and the years of design judgment behind it belongs to its author. If this fork is useful to you and you can spare it, please consider supporting the original project at [tryvoiceink.com](https://tryvoiceink.com) — the paid release funds continued development on the upstream side.

Modifications and additions in this fork are documented in the git commit history.

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
</content>
</invoke>
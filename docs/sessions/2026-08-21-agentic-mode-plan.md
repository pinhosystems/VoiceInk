# Agentic Mode Plan (2026-08-21)

> **Status update (same day):** Phase 1 implemented with **AgentRunKit 5.5.0**
> (github.com/Tom-Ryder/AgentRunKit, MIT) as the agent-loop/tooling library —
> the user asked for a standardized, provider-agnostic lib instead of a
> hand-rolled loop. Deployment target bumped 14.4 → 15.0 (AgentRunKit
> requirement). The router runs a bounded tool loop (maxIterations 6) with
> type-safe tools instead of the single structured-output call described
> below; the decision/whitelist/apply/restore design is unchanged. MCP
> exposure of the same tool catalog stays planned for Phase 2 —
> AgentRunKit ships an MCP client, and the official MCP Swift SDK covers
> the server side when we externalize the tools.

Goal: while dictating, the user can speak meta-instructions in natural language ("isso aqui é um email formal", "manda pro Discord, tom informal", "só copia, não cola") and an LLM agent — not a fixed trigger word — interprets them, reconfigures the pipeline (prompt, profile, output language, delivery, autosend), strips the instructions from the text, runs the enhancement, and delivers the result.

## Architecture decision: in-process router vs .NET/Semantic Kernel sidecar

**Recommendation: in-process, in Swift, reusing the existing enhancement stack.** Reasons:

- The app already has multi-provider LLM clients (`AIEnhancementService.makeRequest` routes to Ollama, local CLI, Anthropic, OpenAI-compatible), the prompt catalog, the profile catalog, and the session apply/restore machinery (`PowerModeSessionManager`). A .NET sidecar would duplicate provider configs and API keys, add IPC, a second runtime to ship/launch/update, and a failure mode ("agent process not running") in the middle of every dictation.
- Semantic Kernel buys tool-orchestration plumbing we can get from plain function calling / structured output on the models we already call.
- The design below still keeps a **protocol boundary** (`AgenticBackend`) so a localhost sidecar (SK or anything else) can be plugged in later as an alternative backend if wanted — the tool catalog is the contract.

## Phase 1 — Router v1 (single structured-output call) — the 80% win

One extra LLM call between STT and enhancement. No tool loop, deterministic pipeline, ~300–800 ms with a small model.

### Flow

```
STT text
  → [agentic mode ON?] AgenticRouterService.route(text, context)
       context = { catalog of prompts (id, title, description, category),
                   catalog of profiles (id, name, emoji, description of what they change),
                   current defaults (active prompt, active profile, output language, delivery),
                   frontmost app bundle id / name }
       returns Decision (JSON, structured output):
         {
           "directive_found": bool,
           "actions": [
             {"type":"select_prompt",  "prompt_id":"..."},
             {"type":"activate_profile","profile_id":"..."} | {"type":"clear_profile"},
             {"type":"set_output_language","code":"en"},
             {"type":"set_delivery","mode":"paste"|"clipboard_only"},
             {"type":"set_autosend","key":"none"|"enter"|...}
           ],
           "scope": "this_dictation" | "session",
           "text": "<transcript with the spoken directives stripped>"
         }
  → apply actions (respecting the user's allowed-actions checklist)
  → normal enhancement with the resulting prompt/profile
  → deliver (paste or clipboard-only) → restore if scope == this_dictation
```

### Key behaviors

- **Default = no change.** Router prompt is instructed: only emit actions when the utterance clearly contains a meta-instruction *about the dictation itself*; content that merely mentions email/Discord is NOT a directive. On any doubt, `directive_found: false` and the pipeline behaves exactly as today.
- **Scope**: "isso aqui é email formal" → `this_dictation` (restore after paste, same semantics as trigger words today, via the existing `PromptDetectionService.restoreOriginalSettings` pattern). "a partir de agora modo código" → `session` (persists like the manual switchers; plays with `powerModePersistConfig`).
- **Fallback chain**: router error/timeout (~2.5 s cap) → existing trigger-word detection → unchanged pipeline. Agentic mode never blocks a dictation.
- **Delivery tool** (new small feature): `clipboard_only` skips `CursorPaster.startPasteAtCursor` and only sets the clipboard — this is the "retornar e salvar no clipboard" ask, also useful outside agentic mode.
- **Transparency**: decision logged into the transcription's `APICallLog` (router request/response as a Step) and surfaced in History ("Agent: Email — Formal, session"). NotificationManager toast when a switch happens.

### Settings UI (Enhancement screen, new "Agentic Mode" section)

- Enable toggle (off by default).
- Router model picker — independent of the enhancement model; default to a small/fast model (local Ollama qualifies).
- **Allowed actions checklist** (the "defaults" ask): prompt switch / profile switch / output language / delivery / autosend — each can be locked. Locked action → router still parses but the action is dropped (and logged).
- Default scope picker (this dictation / session) for when the user doesn't say.

### Files (estimate M–L, ~1 day)

- `VoiceInk/Services/AIEnhancement/AgenticRouterService.swift` — new: context assembly, router system prompt, JSON schema, one `makeRequest`-style call, Decision parsing/validation (ids validated against catalogs).
- `TranscriptionPipeline.swift` — insert router step before the trigger-word block; apply/restore; delivery flag at the paste site.
- `AIEnhancementService` / `PowerModeSessionManager` — no structural change; router calls existing APIs (`setActivePrompt`, `beginSession`, overrides).
- `EnhancementSettingsView` — Agentic Mode section.
- Router prompt lives in `AIPrompts` (versioned like the others).

## Phase 2 — Tool-loop agent v2 (function calling)

Upgrade the router into a real agent when v1 shows its limits (multi-step reasoning, needing context before deciding):

- Provider-native function calling (OpenAI tools / Anthropic tool use; Ollama supports tools on capable models), loop capped at ~4 iterations.
- Extra read tools become useful here: `capture_screen_context()`, `get_clipboard()`, `list_prompts/list_profiles` on demand instead of stuffed into the context, `lookup_vocabulary(term)`.
- Same Decision application layer — the loop only *gathers*; mutations still go through the whitelist.
- `AgenticBackend` protocol formalized here; a localhost HTTP backend (e.g. the user's .NET Semantic Kernel service) becomes a drop-in alternative implementing the same tool contract.

Estimate L (2–3 days), only after v1 feedback.

## Tool catalog (what existing functionality gets exposed)

| Tool | Backs onto | Phase |
|---|---|---|
| `list_prompts()` | `AIEnhancementService.allPrompts` (id, title, description, category) | 1 (in context) / 2 (on demand) |
| `select_prompt(id)` | `setActivePrompt` + restore machinery | 1 |
| `list_profiles()` | `PowerModeManager.configurations` | 1 (in context) / 2 |
| `activate_profile(id)` / `clear_profile()` | `setActiveConfiguration` + `beginSession`/`endSession` | 1 |
| `set_output_language(code)` | LLM output-language override (`LocalePackRegistry.outputLanguageCode`) | 1 |
| `set_delivery(paste\|clipboard_only)` | new flag at the paste site | 1 |
| `set_autosend(key)` | `autoSendKey` for this delivery | 1 |
| `capture_screen_context()` | `ScreenCaptureService` (gated on permission + user toggle) | 2 |
| `get_clipboard()` | `lastCapturedClipboard` (gated on context toggle) | 2 |
| `lookup_vocabulary(term)` | `CustomVocabularyService` | 2 |
| `set_tone(formal\|casual)` | sugar → maps to the Email — Formal/Casual pair or appends a register rule | 1 (via prompt selection) |

**Deliberately NOT exposed**: provider/API-key management, model downloads, deleting/creating prompts or profiles, Settings mutations outside the whitelist. Agent reconfigures a dictation; it does not administer the app.

## Defaults model (question 3)

- **Pre-enabled defaults** = what already exists: global selected prompt + fallback profile; agentic mode starts every dictation from them.
- **Per-dictation overrides** = router actions with `scope: this_dictation` (auto-restored).
- **Session overrides** = `scope: session`, reverted by the same paths that exist today (profile switchers, `powerModePersistConfig`).
- **Locks** = allowed-actions checklist; anything unchecked is never touched by the agent.

## Risks / open points

- False positives (content mistaken for directive) — mitigated by conservative router prompt + whitelist + visible toast + easy undo (History re-enhance).
- Latency: +1 small-model call per dictation while enabled; short utterances could optionally skip the router (reuse the existing short-utterance threshold).
- Cost: user-controlled via router model picker (local model = free).
- PT/EN mixed directives: router prompt gets few-shot examples in both languages.

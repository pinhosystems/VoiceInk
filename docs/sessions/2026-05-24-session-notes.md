# Session notes — 2026-05-24

Branch: `refactor/providers-tab` (NOT yet pushed; local-only).
Commits ahead of `origin/refactor/providers-tab`: **23** at the time of
this note. **Do not push to GitHub** — the upstream repo is public and
the user explicitly opted out of publishing this session's work.

## Purpose of this file

Token-budget triage. Compress the long live conversation into a written
record so the next session can rehydrate quickly without dragging the
entire chat history forward.

---

## Commit timeline (oldest → newest)

| Hash | Subject |
|------|---------|
| `6788be6` | Simplify Dictionary screen and clarify Vocabulary vs Word Replacement |
| `0bb4e39` | Dictionary: locale-keyed bulk-add template flow |
| `faedaa3` | Normalize the normalization UI and update the pt-BR test surface |
| `c4e1a85` | Add Tier 1 locale packs for es / fr / de / it / ja / ko / zh |
| `90cc732` | Power Mode: section-level Customize toggles |
| `1259ce3` | Power Mode: relabel "Set as default" to "Use as fallback profile" |
| `ba84cac` | Dictionary: provenance strip + clearer pipeline-stage copy |
| `4e5dae1` | Enhancement: drive normalization examples off the output-language pack |
| `aeede36` | Add OpenAI cloud STT and clean up provider capability flags |
| `40df563` | Enhancement: surface Context + Locale inline, slim the gear panel |
| `310feb2` | Enhancement: Power Mode badge and inline test sandbox |
| `5e4c208` | PromptEditor: show vocabulary domains and link to Dictionary |
| `a34448e` | Sandbox: prompt picker + per-run prompt-text override |
| `6bcc90b` | Add default app language with primary-subtag fallback propagation |
| `0287428` | Onboarding language gate + adaptive greeting; drop "(generic)" labels |
| `e53e5cf` | Power Mode language: Default sentinel inheriting global selection |
| `8a44eaf` | Settings: reorganize into 6-tab layout |
| `8cd4844` | Language audit: honor DefaultAppLanguage in model swap, Apple Native fallback, and backup round-trip |
| `9928719` | Settings: lift the tab strip off the window chrome and pad each tab top |
| `20cadfa` | Power Mode: always-on, drop the disable toggle and legacy UI gate |
| `108eee0` | Power Mode is the default mode: copy reframe |
| `e99001e` | Rename Power Mode → Profiles (Perfis) and remove the disable flow |
| `2f56f04` | Dictionary: hide from sidebar, expose only inside Settings → Advanced |

---

## Architectural decisions in effect

### 1. Default App Language is the single source-of-truth
- New `DefaultAppLanguage` UserDefault, seeded from `Locale.current`.
- New helper `LanguageFallbackResolver` (in `VoiceInk/Locale/`) resolves
  any target against any per-context available list with priority:
  exact → generic primary subtag → sibling region → "auto" → nil.
- New helper `LanguageDefaultPropagator.apply(_:sttModelLanguages:sttValidator:)`
  pushes a chosen default into `SelectedLanguage` and the LLM output
  language at the same time, honoring provider-specific quirks via
  `TranscriptionLanguageSupport.validLanguageOrFallback`.
- The mandatory onboarding step `OnboardingLanguageView` writes
  `DefaultAppLanguage` and flips `DefaultAppLanguageConfirmed = true`.
  Existing installs that already completed onboarding get the flag
  flipped automatically on launch via
  `AppDefaults.markDefaultAppLanguageConfirmedForExistingInstalls`.
- Backup/Restore round-trips the three keys (`DefaultAppLanguage`,
  `SelectedLanguage`, `LLMOutputLanguage`); importing a backup also
  flips `DefaultAppLanguageConfirmed = true` so the gate does not
  re-prompt.

### 2. "Power Mode" is now "Profiles" (Perfis in PT)
- User-facing rename only. Swift symbol names (`PowerModeConfig`,
  `PowerModeManager`, `PowerModeSessionManager`, …) and file paths
  (`VoiceInk/PowerMode/…`) stay as-is for now — that is a separate
  follow-up.
- Profiles are **always on**. Setting `powerModeUIFlag` to `true` is now
  the registered default and a one-shot migration flips legacy `false`
  values to `true`. No UI exposes a disable toggle anymore.
- Individual profiles cannot be disabled either. `PowerModeConfig.init`
  and Codable decode coerce `isEnabled = true`. The per-card enable
  switch and the "Disabled" badge are gone. The cross-profile conflict
  menu in `AppPicker` lost its "Disable other" action.
- `duplicateConfiguration` now creates the copy with `isEnabled = true`
  (was `false`). Users must rename or edit the duplicate before saving
  if they want exclusive ownership of an app.
- Fallback chain at runtime (unchanged from before, lives in
  `ActiveWindowService`): URL match → app match → `isDefault` profile
  → no session → user defaults stay in effect.

### 3. Settings is six tabs
General · Shortcuts · Recording · Profiles · Data · Advanced. Each tab
is a separate `Form` with `.padding(.top, 12)` and the outer `TabView`
sits in a `VStack` with a 16pt top spacer so the tab strip does not
glue itself to the window chrome.

Tab contents:
- General: Language picker (mandatory primary), Hide Dock, Launch at
  Login, Show Announcements, Reset Onboarding.
- Shortcuts: main + additional shortcuts, custom cancel, middle-click.
- Recording: sound, mute, restore clipboard, AppleScript paste, recorder
  style (notch / mini).
- Profiles: explanatory header + Persist Configured Preferences toggle.
- Data: Privacy (audio cleanup) + Backup (export/import).
- Advanced: Experimental + Dictionary entry-point button + Diagnostics.

### 4. Dictionary is a secondary feature
- Sidebar drops `.dictionary` from the "Voice Pipeline" section.
- `Settings → Advanced` exposes an "Open Dictionary…" button that posts
  `.navigateToDestination` with `destination: "Dictionary"`. The route
  stays alive; only the entry point moved.
- `DictionarySettingsView` itself was simplified earlier in the session:
  segmented Picker instead of cards, pipeline strip header, clearer
  Vocabulary-vs-Word-Replacement copy, locale-keyed bulk-add template
  flow.

### 5. Enhancement screen restructured (Phase A + B)
- "Transcription Profiles" section renamed to "Prompts".
- `EnhancementContextSection` and `EnhancementLocaleSection` moved out
  of the gear sliding panel into the main screen.
- The slimmed gear panel keeps Short-skip, Request Timeout, Shortcuts.
- New `EnhancementPowerModeBanner` (still uses the old type name)
  appears at the top whenever a profile is active.
- New `EnhancementTestSection` is a sandbox: prompt picker + optional
  prompt-text override + input/output + Run button. Calls
  `AIEnhancementService.enhance(_:overridePrompt:)` so provider / model
  / context attachments are isolated from the choices in the picker —
  only the prompt is overridden for the run.
- `PromptEditorView` edit mode shows a read-only "Vocabulary Domains"
  row with an "Open Dictionary" link.
- `EnhancementLocaleSection.examplesPack` resolves via
  `LocalePackRegistry.outputLanguageCode(sttCode:)`, so the disclosure
  follows the LLM output language, not the STT language.

### 6. Provider catalog corrections
- OpenAI gained `[.stt, .llm]` capability + a real `OpenAIProvider`
  conforming to `CloudProvider`. Ships `gpt-4o-transcribe`,
  `gpt-4o-mini-transcribe`, and `whisper-1`. Registered in
  `CloudProviderRegistry.allProviders`. New `ModelProvider.openAI` case.
- `AssemblyAI`, `Deepgram`, `Soniox`, `Speechmatics` lost the `.llm`
  capability flag — they don't expose a general chat-completion path
  the app drives, and the Enhancement screen already excluded them.
  The catalog summary now reflects this honestly.

### 7. LocalePack content
Tier 1 packs landed for `es`, `fr`, `de`, `it`, `ja`, `ko`, `zh` — each
ships a Whisper prompt seed in the target language plus a tuned
`aiPromptFormatRules` block. Input transforms (normalization rules,
abbreviations, vocabulary, fillers) intentionally stay empty until
linguistic validation per locale.

`BrazilianPortuguesePack` gained 6 `normalizationExamples` (CPF, CNPJ,
CEP, "duas horas e meia", "cinquenta por cento", "1500 reais").
`LocalePack` protocol gained the `normalizationExamples` field with a
default `[]` so older packs decode unchanged.

`LocalePackRegistry.pack(for:)` was hardened: exact bcp47 → generic
primary subtag (for region-tagged inputs) → first curated pack with
matching primary subtag (for region-less inputs) → `GenericLocalePack`.
Bare `"pt"` still routes to `BrazilianPortuguesePack` by design in this
fork (Brazilian users default to `"pt"`).

### 8. Test infrastructure
`VoiceInkTests/BrazilianPipelineTests` rewritten to use the new
`LocaleNormalizer.apply(_:pack:)` API plus the registry routing. All
18 tests pass under `xcodebuild test`.

---

## Open follow-ups (loose backlog, not formal TaskList tasks)

The TaskList itself in the live session covered #47–#73 with #56–#73
landing in this session and #64 deleted (Tier-2 locale content needs
empirical STT samples; user explicitly accepted the deferral). What
follows are issues surfaced during the session that did not get
implemented this round:

1. **Symbol rename**: `PowerMode*` Swift symbols and the
   `VoiceInk/PowerMode/` directory still carry the old name. The
   user-facing rename is complete; the code-side rename is a separate
   refactor (file moves + ~50 symbol renames + Xcode pbxproj sync).
2. **Context flags as Profile overrides**: `useSelectedTextContext`,
   `useClipboardContext`, `useScreenCaptureContext` and their per-source
   `maxChars` settings live globally in `AIEnhancementService` and have
   no per-profile override yet. Add as overrides if per-app behavior
   diverges.
3. **Tier 2 locale content** for the new packs (`es/fr/de/it/ja/ko/zh`):
   vocabulary terms, word replacements, fillers, normalization rules.
   Requires real STT samples; do not auto-fill blindly.
4. **Power-mode banner copy** in `EnhancementPowerModeBanner` still
   reads "Power Mode active" — should follow the rename. Same for
   `AudioPlayerView` tooltips, `TranscriptionInfoPanel` label, and
   several Whisper/AppPicker comments that still say "Power Mode".
5. **`PowerModeValidator` alert text** still says "Cannot Save Power
   Mode". Trivial copy-only follow-up.
6. **Onboarding preset gallery** option: pre-seed a small set of
   common profiles (ChatGPT, Cursor, Email) on first launch. Spec-
   discussed, not implemented; current default = empty + falls back to
   user defaults.
7. **Per-locale dictionary audit**: with the locale-keyed bulk-add
   template flow in place, the surfacing logic is right but only
   pt-BR ships content. Tier 2 locale content (#3 above) is the
   underlying blocker.

---

## How to rehydrate in a future session

1. `git log --oneline 9719dc6..HEAD` — full diff scope of this session.
2. Branch tip is `2f56f04`; `9719dc6` is the session-start ancestor.
3. The branch is not pushed and the user explicitly does not want it
   pushed yet. Treat any "should I push" prompt as opt-in only.
4. `docs/MULTILINGUAL_PLAN.md` is still the canonical spec for the
   locale / multilingual side and was last edited earlier in the
   parent session before this one started. Section 7 has the
   resolved-questions log.
5. The TaskList lives in the live runtime, not the repo — it will be
   empty in the next session unless re-created. Use this file's
   follow-ups list to re-seed.

---

## Repository constraints

- **Public repo** (`pinhosystems/VoiceInk`). Do not push without
  explicit user opt-in.
- **No `Co-Authored-By` lines** in commits or PRs (user CLAUDE.md
  preference).
- **No emoji in code/comments** unless user explicitly asks.
- **Code artifacts in English** regardless of conversation language.
- **`make install-local`** after every build; the user runs this fork
  as a daily driver and expects `/Applications/VoiceInk.app` to be
  fresh after each commit.
- **Tests live in `VoiceInkTests`** and currently build via
  `xcodebuild ... test` with the LocalBuild.xcconfig overrides.

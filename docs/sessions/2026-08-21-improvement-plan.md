# Improvement Plan — Prompts, Profiles, Menus, De-Pro (2026-08-21)

Suggestion plan built from a full code map of the prompt system, Power Mode/Profiles, menus, and licensing residue. Items are independent; pick freely. Effort: S (<1h), M (1–3h), L (larger).

Priority guide:
- **P1** — solves the user's stated pain (manual preset switching when dictating emails).
- **P2** — high-value polish.
- **P3** — structural improvements.
- **P4** — cleanups.

---

## 1. Prompts

Current state: 6 predefined prompts always in the picker (`PredefinedPrompts.swift`: Default, Assistant, Task Prompt, Rewrite, Email, Chat) + 4 clonable templates (`PromptTemplates.swift`: System Default, Commit Message, PR Description, Code Review). `PromptCategory` exists (writing / coding / dev_ai / chat) but is metadata only — every picker renders a flat list, and the editor has no category control.

### 1.1 (P1, M) Email tone split + default trigger words
The pain "I have to switch presets manually to write an email" is best solved by **trigger words**, which already exist end-to-end (`PromptDetectionService.swift`): a word spoken at the start/end of the utterance switches the prompt *for that dictation only*, strips itself, and reverts afterwards. It also works inside RDP, where app-based Profile triggers are blind (frontmost app is always `com.microsoft.rdc.macos`).

- Split the predefined **Email** prompt into **Email — Formal** and **Email — Casual** (two predefined entries; formal = greetings like "Prezado/Dear", no contractions; casual = current friendly tone).
- Ship **default trigger words** on predefined prompts, PT + EN, e.g.:
  - Email — Formal: `email formal`, `formal email`, `email` (bare "email" defaults to formal)
  - Email — Casual: `email casual`, `casual email`, `email informal`
  - Chat: `chat`, `mensagem`
  - Task Prompt: `tarefa`, `task`
- Seeding rule: `initializePredefinedPrompts()` (`AIEnhancementService.swift:742-761`) already preserves user-edited trigger words on upsert; seed defaults only when the stored list is empty.
- Email prompt body: add subject-line handling ("If the user dictates a subject, emit a `Subject:` / `Assunto:` line first").

### 1.2 (P2, M) New clonable templates (curated, not forced)
Add to `PromptTemplates.all`, all `category`-tagged:
- **Meeting Notes** — braindump → structured notes (topics, decisions, action items).
- **Status Update** — daily/standup style: what was done, what's next, blockers.
- **Bug Report / Issue** — steps to reproduce, expected vs actual, environment.
Keep the template gallery lean; skip anything speculative.

### 1.3 (P3, M) Use PromptCategory for real
- Sectioned prompt pickers: `ReorderablePromptGrid` (EnhancementSettingsView), menu-bar Prompt submenu (`MenuBarView.swift:60-82`), mini-recorder popover (`EnhancementPromptPopover.swift`).
- Add a **category picker to `PromptEditorView`** — today custom prompts are stuck at `.writing` because the field is not editable in UI.
- `PromptCategory.displayName` / `iconHint` / `orderedCases` currently have zero call sites — this item is what they were built for.

### 1.4 (P2, S) Prompt text/metadata fixes
- "Default" prompt description grammar: "Default mode to improved clarity…" → "Improves clarity and accuracy of the transcription".
- Code Review template uses icon `"checklist"` which is **not** in `PromptIcon.allCases` (`PromptTemplates.swift:141`) — add it to the enum (or swap icon).
- `TechTermSalvage.swift:12-14` doc comment is stale (says only coding/dev_ai prompts get the block; since `AIEnhancementService.swift:300-308` every prompt on non-EN locales gets it).

### 1.5 (P4, S) Surface ⌘1–⌘0 prompt shortcuts
They already work while the recorder is visible (`MiniRecorderShortcutManager.swift:246-290`); show the number badge next to each prompt in `EnhancementPromptPopover` for discoverability.

---

## 2. Profiles (Power Mode) & Presets

Current state: profiles auto-apply by app/URL at recording start; fallback = the `isDefault` profile. Manual switching only via the emoji button **inside the recorder overlay**; ⌥1–⌥0 are hardcoded and recorder-only; per-profile hotkeys always *start a recording*. No menu-bar entry. Presets (6, `PowerModePresets.swift`) are editor seeds only.

### 2.1 (P1, M) Menu bar "Profile: {name}" submenu
Mirror the existing "Prompt: X" submenu in `MenuBarView.swift`: list profiles with checkmark on active, plus "None — clear". Calls `setActiveConfiguration` + `beginSession` / `endSession`. This is the missing always-reachable switcher (today you must open the recorder to switch).

### 2.2 (P2, S) Active-profile indicator on Profiles page
`ConfigurationRow` (`PowerModeViewComponents.swift:104-460`) never reads `activeConfiguration` — add a subtle "Active" ring/badge on the current card.

### 2.3 (P2, M) Preset gallery copy review
Rewrite the 6 preset `description` strings to say *when to use* and *what the output looks like* (one concrete example each). Point the **Email preset** at the new Email — Formal prompt (1.1). Optionally add a **Meetings** preset bound to the Meeting Notes template (1.2). Don't add more presets than that.

### 2.4 (P3, M) Per-profile hotkey mode "switch only"
`PowerModeShortcutManager.swift:69` always calls `toggleMiniRecorder(powerModeId:)`. Add an option (per profile or global) to make the hotkey just activate the profile without starting a recording.

### 2.5 (P4, S–M) Cleanups
- `PowerModeConfig.isEnabled` is force-`true` at init and decode yet still filtered on in ~8 sites — remove field + `enabledConfigurations`.
- `hotkeyShortcut` stores the sentinel string `"configured"` (`PowerModeConfigView.swift:882-883`) — derive presence from the KeyboardShortcuts store instead.
- "Profiles" appears twice in the IA: sidebar item *and* Settings → Profiles tab (`SettingsView.swift`, `PowerModeSection()`). Fold the Settings tab into the main Profiles screen or reduce it to a pointer.
- Duplicate-trigger conflict has two mental models: `PowerModeValidator` hard-rejects at save; `AppPickerPopover` shows a soft "Also in:" badge with priority guidance. Pick one (suggest: soft badge + priority, drop the hard reject).

### Note — RDP reality
App/URL triggers cannot see apps inside an RDP session. For dictating email in remote Windows, trigger words (1.1) are the mechanism that actually works; document that in the preset gallery or InfoTip.

---

## 3. Menu bar menu reorganization

Current menu (`MenuBarView.swift`) has 7 consecutive submenus with no grouping. Suggested order with dividers:

1. Toggle Recorder
2. — **Transcription**: Transcription Model, Language, Audio Input
3. — **Enhancement**: LLM Enhancement toggle, Prompt, AI Provider, AI Model, Context Sources
4. — **Profile** (new, item 2.1)
5. — **Actions**: Retry Last, Copy Last (⇧⌘C), History (⇧⌘H)
6. — **App**: Settings (⌘,), Show/Hide Dock Icon, Launch at Login
7. — Help and Support / Quit

Plus: "Audio Input" is the only submenu not showing its current value inline — add `: {device}` (S).

---

## 4. De-Pro / "VoiceInk Free" rebrand

The fork already stripped ~70% of commerce. Remaining residue, in tiers (each independently shippable):

- **Tier 1 (P2, S) — the only behavioral gate**: `TranscriptionPipeline.swift:249-254` prepends "Your trial has expired. Upgrade to VoiceInk Pro…" to pasted text on `.trialExpired`. Delete the block and the `licenseViewModel` property (`:16, :26`). (LOCAL_BUILD is always `.licensed`, but the code is a landmine.)
- **Tier 2 (P2, S) — visible branding**: remove both always-on "PRO" chips (`ContentView.swift:233-241`, `:388-396`); collapse `visibleSections`/`prioritizeProviders` conversion-funnel ordering (`:138-165`) to plain `SidebarSection.allSections`; `SystemInfoService.swift:218-229` → report "Community build".
- **Tier 3 (P3, S) — delete orphaned files**: `Views/LicenseView.swift`, `Views/Components/TrialMessageView.swift`, `Views/Components/ProBadge.swift` (project uses synchronized groups; file deletion is enough).
- **Tier 4 (P3, M) — delete the license subsystem**: `PolarService.swift`, `LicenseManager.swift`, `LicenseViewModel.swift` + fallout (`VoiceInkEngine.swift:303-319` observer, `MetricsView.swift:9,20`, `MetricsContent` dead `licenseState`, `.licenseStatusChanged`, UserDefaults keys). Check `Obfuscator.getDeviceIdentifier()` for non-license callers before removing. **Keep the `LOCAL_BUILD` flag** — it still gates Keychain access groups, CloudKit, and bundle-id migration.
- **Tier 5 (P4, S) — optional**: repoint/remove the 7 `tryvoiceink.com/docs` deep links; rename `ViewType.license` → `about` (keep the `"VoiceInk Pro"` routing string as legacy alias).

Branding recommendation: don't literally rename to "VoiceInk Free" — just remove "Pro" everywhere and let the About screen say it's a community build.

---

## Suggested execution order

1. **1.1** Email split + trigger words (P1 — kills the daily pain)
2. **2.1** Menu-bar Profile submenu (P1)
3. **1.4 + 2.2 + 4 Tier 1–2** (quick wins, one small PR)
4. **1.2 + 2.3** templates + preset copy (one PR)
5. **3** menu reorg
6. **1.3** category grouping
7. **4 Tier 3–4 + 2.5** cleanups

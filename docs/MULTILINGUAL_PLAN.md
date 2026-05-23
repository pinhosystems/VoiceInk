# Multilingual Pipeline Plan

> Status: Approved, not yet implemented. Source of truth for the
> refactor that moves the app from a hardcoded pt-BR pipeline to a
> truly multilingual one. Future sessions: read this file front-to-
> back before touching any code.

## 0. Reading guide

This document is structured for an LLM (or human) picking up the
refactor in a future session with no prior context. The order is
deliberate — do not skip ahead.

1. Section 1 — **What "multilingual" means here**, so you don't
   widen scope beyond what was agreed.
2. Section 2 — **Current state** (everything pt-specific in the
   codebase as of the writing date). If anything in this list no
   longer matches the repo, **revise this document first** before
   doing implementation work.
3. Section 3 — **Target architecture** (what should exist after the
   refactor). Includes the file layout.
4. Section 4 — **Phased execution plan** with one buildable +
   installable commit per phase. Follow in order.
5. Section 5 — **Revision guidelines** for keeping this document
   honest as the work progresses.
6. Section 6 — **Adding a new locale pack** (the steady-state flow
   after the refactor lands).
7. Section 7 — **Open questions / pending details** that we
   intentionally deferred. Resolve before / during implementation.

## 1. What "multilingual" means here

Two distinct definitions, both load-bearing:

- **Framework-level multilingual**: the codebase has no hardcoded
  references to a single language. All locale-specific behavior
  flows through a `LocalePack` lookup that takes a BCP-47 code and
  returns either a curated pack or a generic fallback. After the
  refactor, adding a new language is a plug-in (new file + one
  registry append) with zero churn elsewhere.
- **Content-level multilingual**: every locale either has a curated
  pack (hand-curated regex, vocabulary, fillers, prompts) or falls
  back to a generic minimum (audio-language hint + tech-term
  salvage + generic format-rules instruction). The user always
  experiences *something* tuned to their language; we just don't
  promise *equal depth* across languages.

The refactor must deliver both. The PortuguesePack ships with the
curated content currently in the BR files; every other non-English
locale gets the generic fallback until someone curates a pack for
it.

## 2. Current state (audit as of 2026-05-23)

| # | Component | Path | What is pt-specific |
|---|---|---|---|
| 1 | Text normalizer | `VoiceInk/Transcription/Processing/BrazilianTextNormalizer.swift` | Regex rules for CPF, CNPJ, CEP, R$, dd/mm/aaaa dates, "duas horas e meia", "cinquenta por cento". 390 LOC. |
| 2 | Word replacements | `VoiceInk/Models/BrazilianWordReplacements.swift` | Chat abbreviation table: vc→você, tb→também, pq→porque, obg→obrigado, etc. 75 LOC. |
| 3 | Vocabulary template | `VoiceInk/Models/BrazilianVocabularyTemplate.swift` | High-frequency BR words with non-trivial spelling (accents, proper nouns). 112 LOC. |
| 4 | Filler words | `VoiceInk/Transcription/Processing/FillerWordManager.swift` (`brazilianPortugueseFillerWords`) | "né", "tipo", "sei lá", "aí", etc. |
| 5 | Whisper prompt seed | `VoiceInk/Transcription/Whisper/WhisperPrompt.swift` (`WhisperPromptDomain.brazilian` + seed copy) | Hint string nudging Whisper to write pt-BR with diacritics and BR conventions. |
| 6 | AI locale rules block | `VoiceInk/Models/AIPrompts.swift` (`localeRulesBlock`) | Inline pt-BR / pt-PT / English formatting hardcoded inside the static string. |
| 7 | Vocabulary domain enum | `VoiceInk/Models/VocabularyDomain.swift` (`case brazilian`) | Hardcoded BR case. |
| 8 | Whisper prompt domain enum | `VoiceInk/Transcription/Whisper/WhisperPrompt.swift` (`WhisperPromptDomain.brazilian`) | Hardcoded BR case. |
| 9 | UserDefault key | `VoiceInk/AppDefaults.swift` (`BrazilianNormalizationEnabled`) | Specific to BR normalizer. |
| 10 | Settings toggle copy | `VoiceInk/Views/Settings/SettingsView.swift` | "Brazilian normalization" label hardcoded. |
| 11 | UI buttons | `VoiceInk/Views/Dictionary/WordReplacementView.swift`, `VoiceInk/Views/Dictionary/VocabularyView.swift` | "Add pt-BR abbreviations" / "Add pt-BR vocabulary". |
| 12 | Pipeline application | `VoiceInk/Transcription/Engine/TranscriptionPipeline.swift` | Calls `BrazilianTextNormalizer.isEnabled(for:)` + `normalize(...)`. |
| 13 | Vocabulary resolver | `VoiceInk/Services/VocabularyResolver.swift` | Iterates `VocabularyDomain.brazilian` and hardcodes the domain priority `[.userVocabulary, .technical, .brazilian]`. Direct consumer of item 7; must change alongside it in Phase 4. |
| 14 | Output filter comments | `VoiceInk/Transcription/Processing/TranscriptionOutputFilter.swift` | Two pt-BR references are in comments only (lines ~68, ~101). Logic is generic. No code change required; touch only if comments mislead future readers. |

Components that are **already generic** and need no work:

| # | Component | Path | Notes |
|---|---|---|---|
| A | Audio language hint | `VoiceInk/Models/AIPrompts.swift` (`audioLanguageBlock`) | Uses `Locale` API — works for any code. |
| B | Tech-term salvage | `VoiceInk/Models/TechTermSalvage.swift` | Curated tables for pt/es, generic fallback for any non-EN locale. |
| C | Cloud STT `keyterm` / `customVocabulary` plumbing | `VoiceInk/Transcription/Cloud/*` | Already takes a flat `[String]` from VocabularyResolver — switches automatically once VocabularyResolver reads from the locale pack. |

## 3. Target architecture

### 3.1 Files (new)

```
VoiceInk/Locale/
├── LocalePack.swift              # Protocol + NormalizerRule struct
├── LocalePackRegistry.swift      # Lookup with curated → generic → nil fallback chain
├── LocaleNormalizer.swift        # Applies NormalizerRule[] to a String
└── Packs/
    ├── GenericLocalePack.swift   # Fallback for any non-EN locale without a curated pack
    └── PortuguesePack.swift      # All content from the four Brazilian* files
```

### 3.2 Files (deleted after Phase 7)

```
VoiceInk/Transcription/Processing/BrazilianTextNormalizer.swift
VoiceInk/Models/BrazilianWordReplacements.swift
VoiceInk/Models/BrazilianVocabularyTemplate.swift
```

(`FillerWordManager.brazilianPortugueseFillerWords` and
`WhisperPromptDomain.brazilian` get pulled into PortuguesePack but
their host files stay — we just remove the hardcoded BR-only
branch.)

### 3.3 Protocol shape

```swift
protocol LocalePack {
    var primarySubtag: String { get }                       // "pt", "es"
    var displayName: String { get }                         // "Brazilian Portuguese"

    var normalizerRules: [NormalizerRule] { get }
    var wordReplacements: [(original: String, replacement: String)] { get }
    var vocabularyTerms: [String] { get }
    var fillerWords: [String] { get }
    var whisperPromptSeeds: [String: String] { get }        // domain (e.g. "default", "technical") → seed copy
    var aiPromptFormatRules: String { get }                 // becomes the <LOCALE_RULES> block content
}

struct NormalizerRule {
    let pattern: NSRegularExpression
    let replacement: String
    let description: String                                  // logged + shown in debug builds
}
```

### 3.4 Registry contract

```swift
enum LocalePackRegistry {
    /// Curated packs ship with the binary. Append a new pack here
    /// after creating the file under Locale/Packs.
    private static let curated: [LocalePack] = [PortuguesePack()]

    /// Resolves a BCP-47 code (e.g. "pt-BR", "es-MX") through three
    /// tiers:
    ///   1. Curated pack whose `primarySubtag` matches the input's
    ///      primary subtag.
    ///   2. `GenericLocalePack` synthesized from the primary subtag
    ///      for any non-English locale without curated content.
    ///   3. nil for English (en, en-*), "auto", and empty values.
    static func pack(for languageCode: String?) -> LocalePack?
}
```

## 4. Phased execution plan

Each phase is **one commit** that builds and installs cleanly. Do
not bundle phases — keep blast radius small so any phase can be
reverted in isolation.

### Phase 1 — `LocalePack` protocol + supporting types

- New file: `VoiceInk/Locale/LocalePack.swift` with the protocol +
  `NormalizerRule` struct.
- New file: `VoiceInk/Locale/LocaleNormalizer.swift` with a single
  `static func apply(_:rules:) -> String` that runs the rules
  sequentially and logs description per match in debug builds.
- No consumer changes. The protocol exists in isolation; nothing
  imports it yet.
- Build + `make install-local`. App behavior unchanged.

### Phase 2 — `PortuguesePack` extraction

- New file: `VoiceInk/Locale/Packs/PortuguesePack.swift` containing
  every BR content list previously in:
    - `BrazilianTextNormalizer.swift` (regex → `normalizerRules`)
    - `BrazilianWordReplacements.swift` → `wordReplacements`
    - `BrazilianVocabularyTemplate.swift` → `vocabularyTerms`
    - `FillerWordManager.brazilianPortugueseFillerWords` →
      `fillerWords`
    - `WhisperPrompt`'s BR seed copy → `whisperPromptSeeds`
    - The pt-BR / pt-PT lines inside `AIPrompts.localeRulesBlock`
      → `aiPromptFormatRules`
- Source code is reproduced verbatim — same regex, same lists,
  same seed strings. Tests of `BrazilianTextNormalizer` (if any)
  still pass.
- The legacy `Brazilian*` files are **not deleted yet** — they
  stay so the consumers that still reference them keep working.

### Phase 3 — `GenericLocalePack` + `LocalePackRegistry`

- New file: `VoiceInk/Locale/Packs/GenericLocalePack.swift`.
  Synthesizes a pack from any primary subtag:
    - `displayName` via
      `Locale(identifier: "en").localizedString(forLanguageCode:)`
    - `normalizerRules`, `wordReplacements`, `vocabularyTerms`,
      `fillerWords`: empty.
    - `whisperPromptSeeds[\"default\"] = "Transcription in \\(displayName)."`
    - `aiPromptFormatRules = "Use \\(displayName) conventions for
      numbers, dates, currency, and punctuation."`
- New file: `VoiceInk/Locale/LocalePackRegistry.swift` with the
  three-tier `pack(for:)` lookup.
- Still no consumer changes.

### Phase 4 — Refactor STT pipeline + vocabulary + Whisper prompt

- `VocabularyDomain` — replace `case brazilian` with
  `case locale(String)`. Update every switch over it.
  Persisted JSON: write a one-shot decoder that maps the legacy
  `"brazilian"` string to `.locale("pt")` so older CustomPrompts
  decode cleanly.
- `VocabularyResolver` — when a prompt has a `.locale(code)`
  domain, look up the pack via `LocalePackRegistry.pack(for: code)`
  and pull `vocabularyTerms`. Otherwise behave as today.
- `WhisperPromptDomain` — same treatment; `case brazilian` →
  `case locale(String)`. Seed lookup goes through
  `pack?.whisperPromptSeeds[domain]`.
- `TranscriptionPipeline.run` — replace
  `BrazilianTextNormalizer.normalize(text)` with
  ```swift
  if let pack = LocalePackRegistry.pack(for: selectedLanguage),
     LocalePackRegistry.normalizationEnabled {
      text = LocaleNormalizer.apply(text, rules: pack.normalizerRules)
  }
  ```

### Phase 5 — Refactor AIPrompts + FillerWordManager

- `AIPrompts.localeRulesBlock` becomes a function that takes a
  `LocalePack?` and emits the pack's `aiPromptFormatRules` (or a
  default EN block when nil).
  `AIEnhancementService.getSystemMessage` passes the resolved pack.
- `FillerWordManager.effectiveFillerWords` reads from the active
  pack instead of the hardcoded BR list:
  ```swift
  let extras = LocalePackRegistry.pack(for: SelectedLanguage)?.fillerWords ?? []
  ```

### Phase 6 — Migration + Settings UI

- New UserDefault: `LocaleNormalizationEnabled` (bool, default
  true).
- One-shot migration on app launch: if the new key is unset and
  the old `BrazilianNormalizationEnabled` exists, copy its value
  and delete the old key.
- `SettingsView` toggle label becomes dynamic:
  ```swift
  let label = activePack?.displayName ?? "Locale"
  Toggle("\\(label) normalization", isOn: $localeNormEnabled)
  ```
  Disable the toggle when there's no curated pack for the current
  language (so user knows the feature is inert).
- `WordReplacementView` and `VocabularyView` buttons:
  - "Add pt-BR abbreviations" → "Add \\(pack.displayName) abbreviations"
  - Disabled / hidden when active pack has empty
    `wordReplacements` / `vocabularyTerms`.

### Phase 7 — Cleanup + docs

- Delete `BrazilianTextNormalizer.swift`,
  `BrazilianWordReplacements.swift`,
  `BrazilianVocabularyTemplate.swift`.
- Remove `WhisperPromptDomain.brazilian` enum case (was migrated
  to `.locale`).
- Update README's feature list: "Brazilian Portuguese pipeline" →
  "Multilingual pipeline — curated content for pt-* (BR + PT
  share the table). Generic fallback ships for every other non-
  English locale; tech-term salvage covers es-* explicitly. Add
  curated packs in `VoiceInk/Locale/Packs/`."
- Update this document (`MULTILINGUAL_PLAN.md`) to status
  "Implemented" + capture the final file layout if it diverged.

## 5. Revision guidelines

Treat this document as living. Update it when:

- **Reality drifts from Section 2's audit** — if a future commit
  adds a new pt-specific component, append it to the audit
  table *in the same commit*.
- **A phase ships** — change Phase X's heading prefix to
  "Phase X (DONE in <sha>) —" and add the commit hash. Do not
  delete the phase text.
- **An open question in Section 7 is resolved** — move it to the
  appropriate phase or document the decision inline.
- **The protocol shape changes** during implementation — Section
  3.3 must match the actual shipped protocol exactly.
- **A new locale pack is added** — bump the count in the README
  feature list and add the pack to Section 6.1's pack inventory.

Rule: this file is the spec. The repo is the implementation. They
must agree before the plan is considered "done".

## 6. Adding a new locale pack (steady state)

After Phase 7 ships, contributing a curated pack is mechanical.

### 6.1 Pack inventory

| Subtag | Pack name | Status | Source path |
|---|---|---|---|
| pt | `PortuguesePack` | Curated (BR-flavored; covers pt-PT via primary-subtag match) | `VoiceInk/Locale/Packs/PortuguesePack.swift` |
| es | — | Generic fallback only. Curate when patterns observed. | — |
| fr | — | Generic fallback only. | — |
| de | — | Generic fallback only. | — |
| it | — | Generic fallback only. | — |
| ja | — | Generic fallback only. | — |
| zh | — | Generic fallback only. | — |
| en | — | No pack (English is the unmarked default). | — |

Append a row here for every new pack added.

### 6.2 Step-by-step

1. Create `VoiceInk/Locale/Packs/<Language>Pack.swift` conforming
   to `LocalePack`. Use `PortuguesePack` as a reference for
   structure.
2. Curate content from observed STT failures, not from
   imagination. Document the source of each `NormalizerRule` and
   each `wordReplacements` entry in a `description` field /
   trailing comment.
3. Append the new pack's instance to
   `LocalePackRegistry.curated`.
4. Add a row to Section 6.1 of this document.
5. Update the README's feature list to mention the new locale.
6. Commit with a body that links the observation source (issue,
   transcript snippet, user report) for every rule added.

## 7. Open questions / pending details

These were left intentionally undecided during planning. Resolve
before or during implementation; update this section as you go.

### 7.1 Behavior when the user hasn't picked a language

`SelectedLanguage` defaults to "auto" on first launch in some
flows. `LocalePackRegistry.pack(for: "auto")` returns nil. That
means no normalization, no vocab seed, no format-rules block. Is
that the right default, or should we fall through to a heuristic
(e.g. system locale)?

**Decision needed.** Default recommendation: stay nil — auto
means "let Whisper decide", and we should not paper over that
with a locale guess. But this should be confirmed against the
actual STT engines' behavior.

**Resolved 2026-05-23 (pre-Phase-1):** Stay nil. `LocalePackRegistry.pack(for:)`
returns nil for `"auto"`, `nil`, `""`, and any `en*` code. Rationale:
the STT engine is responsible for detecting language when the user
picks "auto"; we should not synthesize a locale-specific pipeline
from a system-locale guess that may not match the audio. The
audio-language hint + tech-term salvage already cover the common
case where Whisper detects a non-EN audio and we still want LLM
guidance — they read the *transcript's* detected language at
runtime, not the user setting.

### 7.2 Pack precedence vs user-curated overrides

When a curated pack ships filler words like "tipo" but the user
removed "tipo" from their personal filler list, what wins?

Current `FillerWordManager.effectiveFillerWords` unions the user
list with the BR list — pack would replicate that. Confirm this
is desired, or whether the user's removal should be a veto.

**Resolved 2026-05-23 (pre-Phase-5):** Phase 5 ships the union
semantics unchanged. `effectiveFillerWords = userList ∪ packList`.
There is no per-user "removed-from-pack" set today, and adding one
is out of scope for this refactor — escalate to a dedicated commit
only if a user reports drift. Same rule applies to
`wordReplacements` and `vocabularyTerms`: the pack is the additive
default; the user list is the source of truth for explicit
additions. Pack-side removals (user wants "tipo" gone from the
filler list) require a future opt-out store.

### 7.3 Word replacement migration

`BrazilianWordReplacements.canonicalReplacements` is a static
list seeded into the user's `WordReplacement` SwiftData rows when
they click "Add pt-BR abbreviations". After the refactor:

- Should existing rows be re-tagged with the new locale label?
- If the user re-clicks "Add Portuguese abbreviations" should we
  detect duplicates (current behavior) or always append?

Confirm before Phase 6.

**Resolved 2026-05-23 (pre-Phase-6):**
- **No re-tagging of existing rows.** The `WordReplacement`
  SwiftData model has no locale column today; adding one is out
  of scope for this refactor. Existing rows stay as-is.
- **Re-click stays idempotent.** Keep current dedup-by-signature
  behavior. Re-seeding from `pack.wordReplacements` is a no-op
  for already-present entries; only net-new rows are inserted.
- Future commits may add a locale column + per-pack re-seed
  filter; that's deferred until a contributor needs it.

### 7.4 Locale-specific number / date formatting in *output*

Right now the normalizer formats pt-BR numbers/dates (e.g. converts
"duas horas e meia" → "2h30") *before* sending to the LLM. The
LLM also gets `<LOCALE_RULES>` telling it how to format pt-BR
output. Two places where pt-BR formatting lives.

For a new locale pack, must contributors curate **both** sets
(input normalization AND output LLM rules) to be consistent? Or
can a pack ship one without the other?

Decide: **both required**, **input only**, or **whatever the
contributor wants** (most flexible). Default recommendation:
input-only is acceptable; output-only is degenerate (LLM has no
input to fix); both is the gold standard.

**Resolved 2026-05-23 (pre-Phase-2/5):**
- **Curated packs MUST provide both** input normalization rules
  and output `aiPromptFormatRules`. Reviewer rejects curated-pack
  PRs missing either side. This keeps the gold standard the only
  shipped depth for curated content.
- **`GenericLocalePack` ships output-only** — empty
  `normalizerRules` + `wordReplacements` + `vocabularyTerms` +
  `fillerWords`, with a single-sentence `aiPromptFormatRules`
  derived from the locale name. That's by design; the generic
  fallback is "tell the LLM the language and let it format". It
  is not subject to the "both required" rule because it ships
  zero curated input rules by construction.

### 7.5 Multiple regions per primary subtag

`PortuguesePack` covers both pt-BR and pt-PT under the same pack
because English tech borrowings behave the same in both registers.
But pt-PT does use "tu" / "vós" and different verb conjugations
that pt-BR users don't.

Eventually some packs may need region-specific content. Should
`LocalePackRegistry` match on full BCP-47 (pt-BR vs pt-PT) instead
of just primary subtag, falling back to the primary match when no
region-specific pack exists?

Defer to **after the refactor** — solve it when the first contributor
wants region-specific content. Document the path then.

**Audit note 2026-05-23:** `VoiceInk/Models/LanguageDictionary.swift`
already encodes a primary→region default (`"pt" → "pt-BR"`,
lines ~95–100). After the refactor, that default is the bridge
between a user who picked plain `"pt"` in some flow and the
`PortuguesePack` (which matches by primary subtag `"pt"`). The
refactor must keep `LocalePackRegistry.pack(for:)` matching on
primary subtag so this fallback stays compatible; region-aware
matching is a future extension that this path will not block.

### 7.6 Power Mode preset prompts and locale

Power Mode presets reference predefined prompts by UUID. After
the refactor, should presets still reference the language-
agnostic Task Prompt and rely on the audio-language hint + tech-
term salvage at runtime, or should there be locale-specific
preset variants?

Current decision (from previous session): keep presets language-
agnostic; the salvage + audio-language hint handle locale at
runtime. This document confirms that decision. Revisit if user
reports the preset prompt isn't enough.

---

## Appendix A — Commit message template

Each phase's commit should follow this template:

```
Phase <N>: <one-line summary>

Plan reference: docs/MULTILINGUAL_PLAN.md, Section 4, Phase <N>.

Scope:
- <bulleted list of changed files>

Behavior change:
- <user-visible delta or "none — refactor only">

Test plan:
- <how the next phase reviewer can verify this>
```

## Appendix B — Files this plan touches

Quick checklist. Update Section 2's table if any of these no longer
exists or moves.

```
DELETE in Phase 7:
  VoiceInk/Transcription/Processing/BrazilianTextNormalizer.swift
  VoiceInk/Models/BrazilianWordReplacements.swift
  VoiceInk/Models/BrazilianVocabularyTemplate.swift

NEW in Phases 1-3:
  VoiceInk/Locale/LocalePack.swift
  VoiceInk/Locale/LocaleNormalizer.swift
  VoiceInk/Locale/LocalePackRegistry.swift
  VoiceInk/Locale/Packs/PortuguesePack.swift
  VoiceInk/Locale/Packs/GenericLocalePack.swift

MODIFIED in Phases 4-6:
  VoiceInk/AppDefaults.swift
  VoiceInk/Models/AIPrompts.swift
  VoiceInk/Models/VocabularyDomain.swift
  VoiceInk/Services/AIEnhancement/AIEnhancementService.swift
  VoiceInk/Services/VocabularyResolver.swift
  VoiceInk/Transcription/Engine/TranscriptionPipeline.swift
  VoiceInk/Transcription/Processing/FillerWordManager.swift
  VoiceInk/Transcription/Whisper/WhisperPrompt.swift
  VoiceInk/Views/Dictionary/VocabularyView.swift
  VoiceInk/Views/Dictionary/WordReplacementView.swift
  VoiceInk/Views/Settings/SettingsView.swift
  README.md
  docs/MULTILINGUAL_PLAN.md  (this file — mark phases done as they ship)
```

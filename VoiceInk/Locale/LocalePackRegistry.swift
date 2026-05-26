import Foundation

/// Resolves a BCP-47 language code to the most specific `LocalePack` available.
///
/// Lookup order:
///   1. Curated pack whose `bcp47` matches the full input (case-insensitive).
///      Example: `"pt-BR"` → `BrazilianPortuguesePack`.
///   2. Region-tagged inputs with no exact pack fall back to a curated generic
///      pack for the primary subtag (`bcp47 == nil`). Example: `"pt-PT"`,
///      `"pt-AO"`, `"pt-MZ"` → `PortuguesePack`.
///   3. Region-less inputs ("pt", "es", ...) fall back to the first curated
///      pack matching the primary subtag. In this fork bare "pt" intentionally
///      resolves to `BrazilianPortuguesePack` — `SelectedLanguage` defaults to
///      "pt" and the dominant user expectation is Brazilian Portuguese.
///   4. `GenericLocalePack` synthesised from the input's primary subtag, for
///      any non-English locale without curated content.
///   5. `nil` for English (`en`, `en-*`), `"auto"`, empty, or nil inputs.
///
/// Section 7.1 of `docs/MULTILINGUAL_PLAN.md` defines the "nil for auto/en"
/// behavior: when the user asks the STT engine to detect language, the
/// pipeline should not pre-emptively apply locale-specific transforms.
enum LocalePackRegistry {
    /// UserDefaults key for the global locale-normalization toggle. Phase 6
    /// owns the migration from the legacy `BrazilianNormalizationEnabled` key;
    /// `normalizationEnabled` below reads either key transparently so Phase 4
    /// can ship without UI changes.
    static let normalizationEnabledKey = "LocaleNormalizationEnabled"
    static let legacyNormalizationEnabledKey = "BrazilianNormalizationEnabled"

    /// UserDefaults key for the LLM-side output-language override.
    /// Sentinel `"match"` (default) routes the LLM through the same pack as
    /// the STT language. Any BCP-47 value here decouples the LLM output
    /// language from the STT input — see `outputLanguageCode(sttCode:)`.
    static let outputLanguageKey = "LLMOutputLanguage"
    static let outputLanguageMatchSentinel = "match"

    /// Effective LLM output language. Returns the STT code when the user has
    /// left the override on `match` (the default); otherwise returns the
    /// explicitly chosen BCP-47 code.
    ///
    /// Callers should pass an already-resolved `sttCode` (i.e. the result of
    /// `LanguageResolver.effectiveSTTCode(...)`) so the chain
    /// Settings → STT → LLM collapses correctly when both are on their
    /// respective sentinels (`"default"` for STT, `"match"` here).
    static func outputLanguageCode(sttCode: String?) -> String? {
        let raw = (UserDefaults.standard.string(forKey: outputLanguageKey) ?? outputLanguageMatchSentinel)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw.lowercased() == outputLanguageMatchSentinel {
            return sttCode
        }
        return raw
    }

    /// Curated packs ship with the binary. Order does not matter — lookup
    /// matches by `bcp47` first, then `primarySubtag`.
    static let curatedPacks: [LocalePack] = [
        BrazilianPortuguesePack(),
        PortuguesePack(),
        SpanishPack(),
        FrenchPack(),
        GermanPack(),
        ItalianPack(),
        JapanesePack(),
        KoreanPack(),
        ChinesePack()
    ]

    /// True when locale-specific input normalization should run. New key wins
    /// if set; otherwise the legacy `BrazilianNormalizationEnabled` value is
    /// honored; otherwise default `true`.
    static var normalizationEnabled: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: normalizationEnabledKey) != nil {
            return defaults.bool(forKey: normalizationEnabledKey)
        }
        if defaults.object(forKey: legacyNormalizationEnabledKey) != nil {
            return defaults.bool(forKey: legacyNormalizationEnabledKey)
        }
        return true
    }

    /// Returns the resolved pack, or nil for English / auto / empty inputs.
    static func pack(for languageCode: String?) -> LocalePack? {
        guard let raw = languageCode?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else { return nil }

        let normalized = raw.lowercased()
        if normalized == "auto" { return nil }

        let primary = normalized.split(separator: "-").first.map(String.init) ?? normalized
        if primary == "en" { return nil }

        // 1. Exact BCP-47 match wins (e.g. "pt-BR" → BrazilianPortuguesePack).
        if let exact = curatedPacks.first(where: { ($0.bcp47?.lowercased()) == normalized }) {
            return exact
        }
        // 2. Region-tagged input with no exact pack falls back to a generic
        //    pack for the primary subtag (e.g. "pt-PT", "pt-AO" → PortuguesePack).
        //    Region-less input ("pt") deliberately skips this branch — see step 3.
        if normalized.contains("-"),
           let generic = curatedPacks.first(where: {
               $0.primarySubtag == primary && $0.bcp47 == nil
           }) {
            return generic
        }
        // 3. Region-less primary subtag picks the first curated pack matching
        //    the subtag. In this fork bare "pt" resolves to BrazilianPortuguesePack
        //    because `SelectedLanguage` defaults to "pt" for Portuguese-speaking
        //    users and the dominant assumption is Brazilian Portuguese (see
        //    `AppDefaults.defaultSelectedLanguage` and the fork README). A user
        //    who specifically wants European Portuguese should pick "pt-PT" or a
        //    future curated pt-PT pack.
        if let primaryMatch = curatedPacks.first(where: { $0.primarySubtag == primary }) {
            return primaryMatch
        }
        return GenericLocalePack(primarySubtag: primary)
    }
}

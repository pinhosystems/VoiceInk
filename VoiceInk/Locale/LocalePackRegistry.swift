import Foundation

/// Resolves a BCP-47 language code to the most specific `LocalePack` available.
///
/// Four-tier lookup, in order:
///   1. Curated pack whose `bcp47` matches the full input (case-insensitive).
///      Example: `"pt-BR"` → `BrazilianPortuguesePack`.
///   2. Curated pack whose `primarySubtag` matches the input's primary
///      subtag. Example: `"pt-PT"`, `"pt-AO"`, plain `"pt"` → `PortuguesePack`.
///   3. `GenericLocalePack` synthesised from the input's primary subtag, for
///      any non-English locale without curated content.
///   4. `nil` for English (`en`, `en-*`), `"auto"`, empty, or nil inputs.
///
/// Section 7.1 of `docs/MULTILINGUAL_PLAN.md` defines the "nil for auto/en"
/// behavior: when the user asks the STT engine to detect language, the
/// pipeline should not pre-emptively apply locale-specific transforms.
enum LocalePackRegistry {
    /// Curated packs ship with the binary. Order does not matter — lookup
    /// matches by `bcp47` first, then `primarySubtag`.
    private static let curated: [LocalePack] = [
        BrazilianPortuguesePack(),
        PortuguesePack()
    ]

    /// Returns the resolved pack, or nil for English / auto / empty inputs.
    static func pack(for languageCode: String?) -> LocalePack? {
        guard let raw = languageCode?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty
        else { return nil }

        let normalized = raw.lowercased()
        if normalized == "auto" { return nil }

        let primary = normalized.split(separator: "-").first.map(String.init) ?? normalized
        if primary == "en" { return nil }

        if let exact = curated.first(where: { ($0.bcp47?.lowercased()) == normalized }) {
            return exact
        }
        if let primaryMatch = curated.first(where: { $0.primarySubtag == primary }) {
            return primaryMatch
        }
        return GenericLocalePack(primarySubtag: primary)
    }
}

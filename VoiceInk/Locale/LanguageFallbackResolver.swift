import Foundation

/// Resolves a BCP-47 target language against a context-specific list of
/// available codes, prioritising a generic variant of the same primary subtag
/// before any other alternative. Used wherever a language picker has to fall
/// back because the exact selection is not in the available set — typically:
///   - Cloud STT provider supports a restricted set of codes.
///   - Hard-coded LLM output-language picker list.
///   - LocalePackRegistry curated pack lookup.
///
/// Lookup order, in priority:
///   1. Exact match against the available list (case-insensitive).
///   2. Generic primary-subtag match: if target is "pt-BR" and the available
///      list contains "pt" (region-less), return "pt".
///   3. Sibling region of the same primary subtag: e.g. target "pt-BR" with
///      available ["pt-PT"] returns "pt-PT".
///   4. "auto" if available.
///   5. nil (caller decides).
///
/// The casing of the returned value comes from the `available` list so the
/// caller writes back whatever the source-of-truth uses (some providers ship
/// "en_US" lowercased, others "en-US"; this helper preserves the original).
enum LanguageFallbackResolver {

    /// Resolves `target` against `available`. Returns nil when no match exists
    /// and the available list has no "auto" entry — caller decides whether to
    /// fall back to a hard-coded default or to surface an error.
    static func resolve(target: String?, available: [String]) -> String? {
        guard let raw = target?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }

        let normalizedTarget = raw.lowercased()

        // 1. Exact match (case-insensitive).
        if let exact = available.first(where: { $0.lowercased() == normalizedTarget }) {
            return exact
        }

        let targetPrimary = primarySubtag(of: normalizedTarget)

        // 2. Generic primary-subtag (region-less) match.
        if let generic = available.first(where: { code in
            let lowered = code.lowercased()
            return lowered == targetPrimary && !lowered.contains("-") && !lowered.contains("_")
        }) {
            return generic
        }

        // 3. Sibling region sharing the same primary subtag.
        if let sibling = available.first(where: { primarySubtag(of: $0.lowercased()) == targetPrimary }) {
            return sibling
        }

        // 4. Auto-detect, if the available list exposes it.
        if let auto = available.first(where: { $0.lowercased() == "auto" }) {
            return auto
        }

        return nil
    }

    /// Convenience: resolves `target`, falling back to `fallback` when no match
    /// is found. Useful when the caller has a sensible default ("auto", "en")
    /// it wants to apply rather than handling nil at every call site.
    static func resolve(target: String?, available: [String], fallback: String) -> String {
        resolve(target: target, available: available) ?? fallback
    }

    /// BCP-47 primary subtag (the part before the first `-` or `_`),
    /// lowercased.
    private static func primarySubtag(of code: String) -> String {
        let lowered = code.lowercased()
        if let hyphen = lowered.firstIndex(of: "-") {
            return String(lowered[..<hyphen])
        }
        if let underscore = lowered.firstIndex(of: "_") {
            return String(lowered[..<underscore])
        }
        return lowered
    }
}

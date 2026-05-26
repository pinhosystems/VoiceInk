import Foundation

/// Announces a change to `DefaultAppLanguage`. This used to push the new
/// value into `SelectedLanguage` and `LLMOutputLanguage` directly, which
/// silently destroyed any explicit customization the user had made in the
/// downstream pickers.
///
/// The architecture is now sentinel-based: AI Models stores `"default"` in
/// `SelectedLanguage` when the user wants to inherit from Settings, and
/// Enhancement stores `"match"` in `LLMOutputLanguage` for the same intent
/// at the LLM step. Resolution happens at every runtime read through
/// `LanguageResolver.effectiveSTTCode(...)` and
/// `LocalePackRegistry.outputLanguageCode(sttCode:)`. The propagator
/// therefore no longer writes anything — it just posts a notification so
/// any open SwiftUI view that displays a resolved label refreshes.
enum LanguageDefaultPropagator {
    /// Posts `.languageDidChange`. Kept as a method (not inlined into the
    /// callers) so onboarding, Settings, and any future entry point share
    /// the exact same notification surface.
    @MainActor
    static func apply(
        _ newDefault: String,
        sttModelLanguages: [String]? = nil,
        sttValidator: ((String) -> String)? = nil
    ) {
        _ = sttModelLanguages
        _ = sttValidator
        let trimmed = newDefault.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        NotificationCenter.default.post(name: .languageDidChange, object: nil)
    }
}

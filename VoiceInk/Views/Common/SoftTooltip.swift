import SwiftUI

/// A lighter, less-outlined alternative to the native `.help(...)` tooltip.
/// Native macOS tooltips render with a bordered yellow-ish box and a 500+ms
/// delay; this modifier shows a soft, material-backed chip after a short
/// hover and removes the box border entirely.
///
/// VoiceOver is preserved via `.accessibilityHint(_:)` so screen-reader
/// users still get the same text the visual tooltip displays.
struct SoftTooltipModifier: ViewModifier {
    let text: String

    @State private var isShowing = false
    @State private var hoverTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .accessibilityHint(text)
            .onHover { hovering in
                hoverTask?.cancel()
                if hovering {
                    hoverTask = Task { [text] in
                        _ = text  // capture so the task survives view churn
                        try? await Task.sleep(nanoseconds: 280_000_000)
                        guard !Task.isCancelled else { return }
                        await MainActor.run { isShowing = true }
                    }
                } else {
                    isShowing = false
                }
            }
            .overlay(alignment: .top) {
                if isShowing {
                    Text(text)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(.regularMaterial)
                                .shadow(color: .black.opacity(0.14), radius: 6, x: 0, y: 2)
                        )
                        .fixedSize()
                        .offset(y: -32)
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .offset(y: 4)))
                        .zIndex(999)
                }
            }
            .animation(.easeOut(duration: 0.18), value: isShowing)
    }
}

extension View {
    /// Show a soft, material-backed tooltip on hover. Use in place of
    /// `.help(_:)` when you want a less-outlined look. Accessibility hint
    /// is set so VoiceOver still announces the text.
    func softTooltip(_ text: String) -> some View {
        modifier(SoftTooltipModifier(text: text))
    }
}

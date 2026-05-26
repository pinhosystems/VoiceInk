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
    /// Measured height of the chip view. Drives the offset that lifts the
    /// chip above the parent — kept in state because the chip height varies
    /// with line count (single-line "Pause" vs. two-line Power Mode copy).
    @State private var chipHeight: CGFloat = 0

    /// Vertical gap between the chip's bottom edge and the parent's top edge.
    private static let chipParentGap: CGFloat = 8

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
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundColor(Color(NSColor.labelColor))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            ZStack {
                                // Solid backing first so the chip never reads as
                                // translucent over the window content; the
                                // material layer on top picks up subtle
                                // vibrancy without bleeding through to the text.
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(NSColor.controlBackgroundColor))
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .opacity(0.6)
                            }
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
                        .shadow(color: .black.opacity(0.06), radius: 1, x: 0, y: 1)
                        .fixedSize()
                        // Measure the chip's actual rendered height. The chip
                        // can be one or several lines tall depending on copy
                        // length (`\n` in the source text, plus future wraps),
                        // and `alignmentGuide(.top)` proved unreliable here
                        // — SwiftUI honored the value on first hover but not
                        // on transitions, so tips ended up rendered BELOW the
                        // button instead of above. A measured offset removes
                        // that ambiguity.
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(
                                        key: TooltipChipHeightKey.self,
                                        value: proxy.size.height
                                    )
                            }
                        )
                        .offset(y: -(chipHeight + Self.chipParentGap))
                        .allowsHitTesting(false)
                        .transition(.opacity.combined(with: .offset(y: 4)))
                        .zIndex(999)
                }
            }
            .animation(.easeOut(duration: 0.18), value: isShowing)
            .onPreferenceChange(TooltipChipHeightKey.self) { newHeight in
                if newHeight > 0 {
                    chipHeight = newHeight
                }
            }
    }
}

/// PreferenceKey carrying the chip's measured height up the view tree so the
/// modifier can offset the overlay precisely.
private struct TooltipChipHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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

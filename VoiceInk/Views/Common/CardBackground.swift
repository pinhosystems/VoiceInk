import SwiftUI

// Style Constants for consistent styling across components
struct StyleConstants {
    // Shared card corner radius. The glassmorphism gradient/border/shadow
    // constants that used to live here were dropped when CardBackground moved
    // to a flat treatment.
    static let cornerRadius: CGFloat = 16
}

// Reusable background component
struct CardBackground: View {
    var isSelected: Bool
    var cornerRadius: CGFloat = StyleConstants.cornerRadius
    var useAccentGradientWhenSelected: Bool = false // This might need rethinking for pure glassmorphism
    
    // Flat, minimal card: a subtle fill and a hairline border, no gradients
    // or shadows. Cards separate from the background by contrast alone, which
    // reads calmer than the previous frosted-glass treatment.
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(
                isSelected
                    ? Color.accentColor.opacity(0.08)
                    : Color(NSColor.controlBackgroundColor).opacity(0.6)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isSelected
                            ? Color.accentColor.opacity(0.35)
                            : Color(NSColor.separatorColor).opacity(0.6),
                        lineWidth: 1
                    )
            )
    }
} 
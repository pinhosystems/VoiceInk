import SwiftUI

/// Browsable grid of Power Mode presets. Used in two places:
/// 1. Inline on the Power Mode landing page when the user has no
///    configs — paired with an empty-state callout so the user knows
///    these cards CREATE new profiles, not just view existing ones.
/// 2. Inside a sliding panel triggered by the "Browse Presets" button.
///
/// The view is purely presentational — applying a preset (cloning the
/// linked prompt, materializing a PowerModeConfig, opening the editor)
/// is the caller's responsibility, wired through `onSelect`.
struct PowerModePresetGallery: View {
    let onSelect: (PowerModePreset) -> Void

    /// One adaptive grid for every preset. Per-category sections used
    /// to wrap each preset in its own section header with a single
    /// card underneath, which on the current 6-preset catalog read
    /// like six tiny one-row sections stacked vertically — exactly
    /// the "everything looks the same" complaint the user filed. A
    /// flat grid keeps the category metadata visible on each card
    /// (as a tag) while letting 2-3 cards share a row.
    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 12, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(PowerModePresets.all) { preset in
                PresetCard(preset: preset, action: { onSelect(preset) })
            }
        }
    }
}

private struct PresetCard: View {
    let preset: PowerModePreset
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Text(preset.emoji)
                        .font(.system(size: 26))
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(NSColor.windowBackgroundColor))
                        )
                    VStack(alignment: .leading, spacing: 3) {
                        Text(preset.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        categoryTag
                        installedFootnote
                    }
                    Spacer(minLength: 0)

                    // Explicit "create from preset" affordance — the
                    // whole card is still clickable, but the chevron
                    // tells the user something will happen if they
                    // do click. Without it the cards read like read-
                    // only summaries of configured profiles.
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.tint)
                        .opacity(isHovering ? 1.0 : 0.5)
                }

                Text(preset.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .shadow(color: .black.opacity(isHovering ? 0.10 : 0.04), radius: isHovering ? 6 : 2, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isHovering ? Color.accentColor.opacity(0.5) : Color(NSColor.separatorColor).opacity(0.4),
                        lineWidth: isHovering ? 1 : 0.5
                    )
            )
            .scaleEffect(isHovering ? 1.01 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovering = hovering
            }
        }
    }

    /// Small uppercase tag identifying the preset's category. Replaces
    /// the per-section header from the older layout — each card now
    /// carries its own classification.
    private var categoryTag: some View {
        Text(preset.category.displayName.uppercased())
            .font(.system(size: 9, weight: .heavy))
            .tracking(0.4)
            .foregroundColor(.secondary.opacity(0.7))
    }

    /// Footnote line summarizing what the preset will actually trigger
    /// on this machine. Counts apps that resolve via NSWorkspace plus
    /// any URL triggers.
    @ViewBuilder
    private var installedFootnote: some View {
        let installed = preset.installedApps().count
        let urls = preset.suggestedURLs.count
        let parts: [String] = {
            var out: [String] = []
            if installed > 0 { out.append("\(installed) app\(installed == 1 ? "" : "s")") }
            if urls > 0 { out.append("\(urls) URL\(urls == 1 ? "" : "s")") }
            if out.isEmpty { out.append("Configure manually") }
            return out
        }()
        Text(parts.joined(separator: " · "))
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary.opacity(0.8))
            .lineLimit(1)
    }
}

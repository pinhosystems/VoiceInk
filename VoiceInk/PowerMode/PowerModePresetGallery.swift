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

    /// Fixed 2-column grid. Adaptive sizing kept collapsing to one
    /// column inside the sliding panel because each PresetCard
    /// reports a wide intrinsic width via its description text — even
    /// at 480pt usable, the layout pass picked a single column.
    /// Pinning to two flexible columns makes the row predictable in
    /// the panel (720pt) and on the inline empty-state (wherever the
    /// content area happens to be wide enough).
    private let columns = [
        GridItem(.flexible(minimum: 240), spacing: 12, alignment: .top),
        GridItem(.flexible(minimum: 240), spacing: 12, alignment: .top),
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
            HStack(alignment: .top, spacing: 12) {
                // Emoji tile with subtle gradient — same visual weight
                // as the ConfigurationRow emoji tile so the two
                // surfaces (browse vs configured) feel like one
                // language.
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.primary.opacity(0.08),
                                    Color.primary.opacity(0.04),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                        .frame(width: 44, height: 44)
                    Text(preset.emoji)
                        .font(.system(size: 22))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(preset.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        // "Add" affordance — the whole card is the
                        // tap target but the icon makes the action
                        // visible without hover. Gets brighter on
                        // hover to confirm the click target.
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.tint)
                            .opacity(isHovering ? 1.0 : 0.6)
                    }

                    installedFootnote

                    Text(preset.description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
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

import SwiftUI

/// Browsable grid of Power Mode presets. Used in two places:
/// 1. Inline on the Power Mode landing page when the user has no configs.
/// 2. Inside a sliding panel triggered by the "Browse Presets" button.
///
/// The view is purely presentational — applying a preset (cloning the
/// linked prompt, materializing a PowerModeConfig, opening the editor)
/// is the caller's responsibility, wired through `onSelect`.
struct PowerModePresetGallery: View {
    let onSelect: (PowerModePreset) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 220, maximum: 260), spacing: 12, alignment: .top)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(PowerModePreset.Category.allCases) { category in
                let presets = PowerModePresets.presets(in: category)
                if !presets.isEmpty {
                    section(title: category.displayName, presets: presets)
                }
            }
        }
    }

    @ViewBuilder
    private func section(title: String, presets: [PowerModePreset]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(presets) { preset in
                    PresetCard(preset: preset, action: { onSelect(preset) })
                }
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
                HStack(alignment: .center, spacing: 10) {
                    Text(preset.emoji)
                        .font(.system(size: 26))
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(NSColor.windowBackgroundColor))
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(preset.name)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        installedFootnote
                    }
                    Spacer(minLength: 0)
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
                    .stroke(Color(NSColor.separatorColor).opacity(isHovering ? 0.8 : 0.4), lineWidth: 1)
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

    /// Subtitle line summarizing what the preset will actually trigger
    /// on this machine. Counts apps that resolve via NSWorkspace plus
    /// any URL triggers; the count is informational, not actionable.
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

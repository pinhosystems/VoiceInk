import SwiftUI

struct AppPickerPopover: View {
    let installedApps: [(url: URL, name: String, bundleId: String, icon: NSImage)]
    @Binding var selectedAppConfigs: [AppConfig]
    @Binding var searchText: String
    /// The Power Mode being edited, if any. When set, the picker excludes
    /// this profile from cross-profile conflict detection so the user does
    /// not see their own selection labelled as a conflict.
    var currentConfigId: UUID? = nil
    /// Lets the parent screen react to the user disabling another profile
    /// from inside the picker (e.g. refresh its own state). Optional.
    var onDisableProfile: ((UUID) -> Void)? = nil

    @ObservedObject private var powerModeManager = PowerModeManager.shared

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Search apps...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(installedApps, id: \.bundleId) { app in
                        let isSelected = selectedAppConfigs.contains(where: { $0.bundleIdentifier == app.bundleId })
                        let conflicts = conflictingProfiles(for: app.bundleId)

                        Button {
                            toggleAppSelection(app)
                        } label: {
                            HStack(spacing: 10) {
                                Image(nsImage: app.icon)
                                    .resizable()
                                    .frame(width: 28, height: 28)
                                    .cornerRadius(6)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name)
                                        .font(.system(size: 13))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)

                                    if !conflicts.isEmpty {
                                        conflictBadge(conflicts: conflicts)
                                    }
                                }

                                Spacer()

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.accentColor)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                            .background(isSelected ? Color.accentColor.opacity(0.08) : Color.clear)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .frame(width: 320, height: 400)
    }

    /// Returns every OTHER enabled profile that already registers this
    /// bundle id. Excludes the profile currently being edited (per
    /// `currentConfigId`) so the user does not see their own selection
    /// echoed back as a conflict.
    private func conflictingProfiles(for bundleId: String) -> [PowerModeConfig] {
        powerModeManager.configurations.filter { config in
            config.id != currentConfigId
                && (config.appConfigs?.contains(where: { $0.bundleIdentifier == bundleId }) ?? false)
        }
    }

    @ViewBuilder
    private func conflictBadge(conflicts: [PowerModeConfig]) -> some View {
        let names = conflicts.map { "\($0.emoji) \($0.name)" }.joined(separator: ", ")
        Menu {
            Text(conflicts.count == 1
                 ? "This app is already in another profile. Both profiles will match — the one higher in the list wins. Edit that profile to remove this app if you want exclusive ownership."
                 : "This app is already in \(conflicts.count) other profiles. The one highest in the list wins. Edit those profiles to remove this app if you want exclusive ownership.")
            Divider()
            ForEach(conflicts) { config in
                Label("\(config.emoji) \(config.name)", systemImage: "doc.text")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 9, weight: .medium))
                Text("Also in: \(names)")
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(.orange)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.orange.opacity(0.12)))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func toggleAppSelection(_ app: (url: URL, name: String, bundleId: String, icon: NSImage)) {
        if let index = selectedAppConfigs.firstIndex(where: { $0.bundleIdentifier == app.bundleId }) {
            selectedAppConfigs.remove(at: index)
        } else {
            selectedAppConfigs.append(AppConfig(bundleIdentifier: app.bundleId, appName: app.name))
        }
    }
}

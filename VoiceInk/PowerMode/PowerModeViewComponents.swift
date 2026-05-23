import SwiftUI

struct VoiceInkButton: View {
    let title: String
    let action: () -> Void
    var isDisabled: Bool = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(isDisabled ? Color.accentColor.opacity(0.5) : Color.accentColor)
                )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

struct PowerModeEmptyStateView: View {
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bolt.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Power Modes")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add customized power modes for different contexts")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VoiceInkButton(
                title: "Add New Power Mode",
                action: action
            )
            .frame(maxWidth: 250)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PowerModeConfigurationsGrid: View {
    @ObservedObject var powerModeManager: PowerModeManager
    let onEditConfig: (PowerModeConfig) -> Void
    @EnvironmentObject var enhancementService: AIEnhancementService

    /// Adaptive 1-to-2 column layout. Below the minimum width we keep
    /// the single full-width column the screen used to ship with —
    /// above ~720pt of available content area the grid breaks into two
    /// columns, which is the common case on the 950pt main window
    /// (sidebar removed). The maximum cap prevents cards from going
    /// absurdly wide on tertiary monitors.
    private let columns: [GridItem] = [
        GridItem(.adaptive(minimum: 340, maximum: 480), spacing: 12, alignment: .top)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach($powerModeManager.configurations) { $config in
                ConfigurationRow(
                    config: $config,
                    isEditing: false,
                    powerModeManager: powerModeManager,
                    onEditConfig: onEditConfig
                )
            }
        }
    }
}

/// Small, consistent icon-only add button used across Power Mode configuration rows.
struct AddIconButton: View {
    let helpText: String
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 18))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(helpText)
        .disabled(isDisabled)
    }
}

struct ConfigurationRow: View {
    @Binding var config: PowerModeConfig
    let isEditing: Bool
    let powerModeManager: PowerModeManager
    let onEditConfig: (PowerModeConfig) -> Void
    @EnvironmentObject var enhancementService: AIEnhancementService
    @EnvironmentObject var transcriptionModelManager: TranscriptionModelManager
    @State private var isHovering = false
    
    private let maxAppIconsToShow = 5
    
    private var selectedPrompt: CustomPrompt? {
        guard let promptId = config.selectedPrompt,
              let uuid = UUID(uuidString: promptId) else { return nil }
        return enhancementService.allPrompts.first { $0.id == uuid }
    }
    
    private var selectedModel: String? {
        if let modelName = config.selectedTranscriptionModelName,
           let model = transcriptionModelManager.allAvailableModels.first(where: { $0.name == modelName }) {
            return model.displayName
        }
        return "Default"
    }
    
    private var selectedLanguage: String? {
        if let langCode = config.selectedLanguage {
            if langCode == "auto" { return "Auto" }
            if langCode == "en" { return "English" }
            
            if let modelName = config.selectedTranscriptionModelName,
               let model = transcriptionModelManager.allAvailableModels.first(where: { $0.name == modelName }),
               let langName = TranscriptionLanguageSupport.languages(for: model)[langCode] {
                return langName
            }
            return langCode.uppercased()
        }
        return "Default"
    }
    
    private var appCount: Int { return config.appConfigs?.count ?? 0 }
    private var websiteCount: Int { return config.urlConfigs?.count ?? 0 }
    
    private var websiteText: String {
        if websiteCount == 0 { return "" }
        return websiteCount == 1 ? "1 Website" : "\(websiteCount) Websites"
    }
    
    private var appText: String {
        if appCount == 0 { return "" }
        return appCount == 1 ? "1 App" : "\(appCount) Apps"
    }
    
    private var extraAppsCount: Int {
        return max(0, appCount - maxAppIconsToShow)
    }
    
    private var visibleAppConfigs: [AppConfig] {
        return Array(config.appConfigs?.prefix(maxAppIconsToShow) ?? [])
    }

    /// Emoji rendered in a soft gradient tile rather than a plain
    /// circle, mirroring the visual weight of macOS app-grid tiles.
    private var emojiTile: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
                .frame(width: 44, height: 44)

            Text(config.emoji)
                .font(.system(size: 22))
        }
    }

    /// Dock-style strip of small app icons + a website count chip, in
    /// place of the older "N Apps · N Websites" text. Falls back to the
    /// text version when no apps + no websites are configured.
    @ViewBuilder
    private var triggersStrip: some View {
        if appCount == 0 && websiteCount == 0 {
            Text("No triggers")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary.opacity(0.7))
        } else {
            HStack(spacing: 4) {
                ForEach(visibleAppConfigs) { appConfig in
                    PowerModeAppIcon(bundleId: appConfig.bundleIdentifier)
                        .frame(width: 18, height: 18)
                }
                if extraAppsCount > 0 {
                    Text("+\(extraAppsCount)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                }
                if websiteCount > 0 {
                    if appCount > 0 {
                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.horizontal, 2)
                    }
                    HStack(spacing: 3) {
                        Image(systemName: "globe")
                            .font(.system(size: 10, weight: .medium))
                        Text(websiteCount == 1 ? "1 site" : "\(websiteCount) sites")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                }
            }
        }
    }
    
    /// Build a pill view used in the bottom summary row. Centralized so
    /// every pill shares typography, padding, and chrome — the previous
    /// version inlined identical Capsule().fill / overlay blocks for
    /// each entry, which made the row drift visually over time.
    @ViewBuilder
    private func summaryPill(icon: String, text: String, tint: Color = .secondary, emphasized: Bool = false) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .foregroundColor(emphasized ? .accentColor : .primary.opacity(0.8))
        .background(
            Capsule().fill(
                emphasized
                    ? Color.accentColor.opacity(0.10)
                    : tint.opacity(0.08)
            )
        )
        .overlay(
            Capsule().stroke(
                emphasized
                    ? Color.accentColor.opacity(0.18)
                    : Color.primary.opacity(0.06),
                lineWidth: 0.5
            )
        )
    }

    private var hasSummaryRow: Bool {
        (selectedModel != nil && selectedModel != "Default")
            || (selectedLanguage != nil && selectedLanguage != "Default")
            || config.isAIEnhancementEnabled
            || config.autoSendKey.isEnabled
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                emojiTile

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(config.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)

                        if config.isDefault {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 5, height: 5)
                                Text("Default")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.accentColor)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.accentColor.opacity(0.10)))
                        }
                    }

                    triggersStrip
                }

                Spacer(minLength: 8)

                Toggle("", isOn: $config.isEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .labelsHidden()
                    .onChange(of: config.isEnabled) { _, _ in
                        powerModeManager.updateConfiguration(config)
                    }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)

            if hasSummaryRow {
                Divider().opacity(0.4)

                HStack(spacing: 6) {
                    if let model = selectedModel, model != "Default" {
                        summaryPill(icon: "waveform", text: model)
                    }
                    if let language = selectedLanguage, language != "Default" {
                        summaryPill(icon: "globe", text: language)
                    }
                    if config.isAIEnhancementEnabled,
                       let modelName = config.selectedAIModel, !modelName.isEmpty {
                        summaryPill(
                            icon: "cpu",
                            text: modelName.count > 20 ? String(modelName.prefix(18)) + "…" : modelName
                        )
                    }
                    if config.autoSendKey.isEnabled {
                        summaryPill(icon: "return", text: config.autoSendKey.displayName)
                    }
                    if config.isAIEnhancementEnabled, config.useScreenCapture {
                        summaryPill(icon: "camera.viewfinder", text: "Context")
                    }
                    if config.isAIEnhancementEnabled {
                        summaryPill(
                            icon: "sparkles",
                            text: selectedPrompt?.title ?? "AI",
                            emphasized: true
                        )
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.primary.opacity(0.025))
            }
    }
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    .background(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(NSColor.windowBackgroundColor))
    )
    .overlay(
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .stroke(
                isHovering ? Color.accentColor.opacity(0.35) : Color.primary.opacity(0.08),
                lineWidth: isHovering ? 1 : 0.5
            )
    )
    .shadow(
        color: .black.opacity(isHovering ? 0.06 : 0.03),
        radius: isHovering ? 6 : 3,
        x: 0,
        y: isHovering ? 2 : 1
    )
    .opacity(config.isEnabled ? 1.0 : 0.55)
    .scaleEffect(isHovering ? 1.005 : 1.0)
    .animation(.easeOut(duration: 0.15), value: isHovering)

    .onHover { hovering in
        isHovering = hovering
    }
    .onTapGesture(count: 2) {
        onEditConfig(config)
    }
    .contextMenu {
        Button(action: {
            onEditConfig(config)
        }) {
            Label("Edit", systemImage: "pencil")
        }
        Button(role: .destructive, action: {
            let alert = NSAlert()
            alert.messageText = "Delete Power Mode?"
            alert.informativeText = "Are you sure you want to delete the '\(config.name)' power mode? This action cannot be undone."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Delete")
            alert.addButton(withTitle: "Cancel")
            alert.buttons[0].hasDestructiveAction = true
            
            if alert.runModal() == .alertFirstButtonReturn {
                powerModeManager.removeConfiguration(with: config.id)
            }
        }) {
            Label("Delete", systemImage: "trash")
        }
    }
    }
    
    private var isSelected: Bool {
        return isEditing
    }
}

struct PowerModeAppIcon: View {
    let bundleId: String
    
    var body: some View {
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: appUrl.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
        }
    }
}

struct AppGridItem: View {
    let app: (url: URL, name: String, bundleId: String, icon: NSImage)
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(nsImage: app.icon)
                    .resizable()
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
                    .shadow(color: Color(NSColor.shadowColor).opacity(0.1), radius: 2, x: 0, y: 1)
                Text(app.name)
                    .font(.system(size: 10))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 28)
            }
            .frame(width: 80, height: 80)
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI
import SwiftData

extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .center,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

enum ConfigurationMode: Hashable {
    case add
    case edit(PowerModeConfig)
    /// Pre-populates the editor with values copied from a Power Mode
    /// preset. The carried `PowerModeConfig` already has the cloned
    /// prompt linked and apps filtered to ones installed on this
    /// machine. Treated as `.add` on save (creates a new entry).
    case addFromPreset(PowerModeConfig)

    var isAdding: Bool {
        switch self {
        case .add, .addFromPreset: return true
        case .edit: return false
        }
    }

    var title: String {
        switch self {
        case .add, .addFromPreset: return "Add Power Mode"
        case .edit: return "Edit Power Mode"
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .add:
            hasher.combine(0)
        case .edit(let config):
            hasher.combine(1)
            hasher.combine(config.id)
        case .addFromPreset(let config):
            hasher.combine(2)
            hasher.combine(config.id)
        }
    }

    static func == (lhs: ConfigurationMode, rhs: ConfigurationMode) -> Bool {
        switch (lhs, rhs) {
        case (.add, .add):
            return true
        case (.edit(let lhsConfig), .edit(let rhsConfig)):
            return lhsConfig.id == rhsConfig.id
        case (.addFromPreset(let lhsConfig), .addFromPreset(let rhsConfig)):
            return lhsConfig.id == rhsConfig.id
        default:
            return false
        }
    }
}

enum ConfigurationType {
    case application
    case website
}

let commonEmojis = ["🏢", "🏠", "💼", "🎮", "📱", "📺", "🎵", "📚", "✏️", "🎨", "🧠", "⚙️", "💻", "🌐", "📝", "📊", "🔍", "💬", "📈", "🔧"]

struct PowerModeView: View {
    @StateObject private var powerModeManager = PowerModeManager.shared
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @EnvironmentObject private var aiService: AIService
    @State private var configurationMode: ConfigurationMode?
    @State private var isPanelOpen = false
    @State private var panelID = UUID()
    @State private var isReorderPanelOpen = false
    @State private var isPresetGalleryOpen = false
    
    var body: some View {
            VStack(spacing: 0) {
                // Header Section
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text("Power Modes")
                                    .font(.system(size: 28, weight: .bold, design: .default))
                                    .foregroundColor(.primary)
                                
                                InfoTip(
                                    "Automatically apply custom configurations based on the app/website you are using.",
                                    learnMoreURL: "https://tryvoiceink.com/docs/power-mode"
                                )
                            }
                            
                            Text("Automate your workflows with context-aware configurations.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button(action: { openPresetGallery() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.grid.2x2.fill")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Browse Presets")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor)
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: { openPanel(mode: .add) }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Blank")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())

                            Button(action: { openReorderPanel() }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.arrow.down")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Reorder")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
                .background(Color(NSColor.windowBackgroundColor))
                
                // Content Section
                Group {
                        GeometryReader { geometry in
                            ScrollView {
                                VStack(spacing: 0) {
                                    if powerModeManager.configurations.isEmpty {
                                        // First-run experience: show a clear
                                        // "no profiles yet" callout above the
                                        // preset gallery so users don't mistake
                                        // the preset cards for configured Power
                                        // Modes that are already firing.
                                        VStack(alignment: .leading, spacing: 18) {
                                            emptyStateCallout
                                                .padding(.top, 24)
                                                .padding(.horizontal, 24)

                                            VStack(alignment: .leading, spacing: 6) {
                                                Text("Start from a preset")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.primary)
                                                Text("Each card creates a new Power Mode prefilled with apps, prompt, and behavior for a common context. Apps you don't have installed are filtered out. Click a card to open the editor and save it.")
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.secondary)
                                                    .lineSpacing(2)
                                            }
                                            .padding(.horizontal, 24)

                                            PowerModePresetGallery(
                                                onSelect: { preset in applyPreset(preset) }
                                            )
                                            .padding(.horizontal, 24)
                                            .padding(.bottom, 40)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    } else {
                                        VStack(spacing: 0) {
                                            PowerModeConfigurationsGrid(
                                                powerModeManager: powerModeManager,
                                                onEditConfig: { config in
                                                    openPanel(mode: .edit(config))
                                                }
                                            )
                                            .padding(.horizontal, 24)
                                            .padding(.vertical, 20)
                                            
                                            Spacer()
                                                .frame(height: 40)
                                        }
                                    }
                                }
                            }
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .background(Color(NSColor.controlBackgroundColor))
            .slidingPanel(isPresented: .init(
                get: { isPanelOpen },
                set: { if !$0 { closePanel() } }
            ), width: 400) {
                if let mode = configurationMode {
                    ConfigurationView(mode: mode, powerModeManager: powerModeManager, onDismiss: closePanel)
                        .id(panelID)
                }
            }
            .slidingPanel(isPresented: .init(
                get: { isReorderPanelOpen },
                set: { if !$0 { closeReorderPanel() } }
            ), width: 400) {
                ReorderPanelView(powerModeManager: powerModeManager, onDismiss: closeReorderPanel)
            }
            .slidingPanel(isPresented: .init(
                get: { isPresetGalleryOpen },
                set: { if !$0 { closePresetGallery() } }
            ), width: 720) {
                VStack(spacing: 0) {
                    // Title row + close. Spans the full panel width so
                    // the close button sits where users habitually
                    // reach for it. Subtitle below sets context so the
                    // panel doesn't read like "list of profiles".
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Power Mode Presets")
                                    .font(.system(size: 18, weight: .semibold))
                                Text("Each card creates a new Power Mode prefilled for a common context.")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: closePresetGallery) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(6)
                                    .background(Color.secondary.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                    .background(Color(NSColor.windowBackgroundColor))
                    .overlay(Divider().opacity(0.5), alignment: .bottom)

                    ScrollView {
                        PowerModePresetGallery(
                            onSelect: { preset in
                                closePresetGallery()
                                applyPreset(preset)
                            }
                        )
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                    }
                }
                .background(Color(NSColor.windowBackgroundColor))
            }
    }

    /// Resolve the preset's prompt link. Three cases:
    ///   1. The ID matches a predefined prompt (Default / Assistant) —
    ///      reuse that UUID directly, no cloning, no duplicates in the
    ///      picker.
    ///   2. The ID matches a template — clone it into a new CustomPrompt
    ///      registered with the enhancement service.
    ///   3. The ID matches nothing — leave the prompt selector empty so
    ///      the user picks one in the editor.
    /// Then open the editor pre-populated with the materialized config.
    private func applyPreset(_ preset: PowerModePreset) {
        var promptID: UUID? = nil
        if PredefinedPrompts.all.contains(where: { $0.id == preset.promptTemplateID }) {
            promptID = preset.promptTemplateID
        } else if let template = PromptTemplates.template(withID: preset.promptTemplateID) {
            let cloned = template.toCustomPrompt()
            enhancementService.customPrompts.append(cloned)
            promptID = cloned.id
        }
        let seed = preset.toConfig(clonedPromptID: promptID)
        openPanel(mode: .addFromPreset(seed))
    }

    /// Banner shown above the empty-state preset gallery. Explicit so
    /// users don't think Power Mode is "running" with whatever they
    /// see below — without any saved configurations, no Power Mode
    /// ever fires, and dictation uses the global Enhancement settings.
    private var emptyStateCallout: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.bubble.fill")
                .font(.system(size: 22))
                .foregroundStyle(.tint)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Power Mode is your default — no profiles yet")
                    .font(.system(size: 14, weight: .semibold))
                Text("Power Mode runs every dictation session. Without profiles, it uses your global Settings (language, transcription model, prompt, LLM provider). Add a profile to override those globally-defined defaults whenever you activate a specific app or visit a specific URL — the fallback chain is profile → user defaults.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.accentColor.opacity(0.20), lineWidth: 1)
        )
    }

    private func openPresetGallery() {
        withAnimation(.smooth(duration: 0.3)) {
            isPresetGalleryOpen = true
        }
    }

    private func closePresetGallery() {
        withAnimation(.smooth(duration: 0.3)) {
            isPresetGalleryOpen = false
        }
    }

    private func openPanel(mode: ConfigurationMode) {
        configurationMode = mode
        panelID = UUID()
        withAnimation(.smooth(duration: 0.3)) {
            isPanelOpen = true
        }
    }

    private func closePanel() {
        withAnimation(.smooth(duration: 0.3)) {
            isPanelOpen = false
            configurationMode = nil
        }
    }

    private func openReorderPanel() {
        withAnimation(.smooth(duration: 0.3)) {
            isReorderPanelOpen = true
        }
    }

    private func closeReorderPanel() {
        withAnimation(.smooth(duration: 0.3)) {
            isReorderPanelOpen = false
        }
    }
}

struct ReorderPanelView: View {
    @ObservedObject var powerModeManager: PowerModeManager
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 12) {
                    Text("Reorder Power Modes")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .padding(6)
                            .background(Color.secondary.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Close")
                }
                Text("Higher in the list = higher priority. When multiple Power Modes match the same app, the first enabled one from the top wins.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Divider().opacity(0.5), alignment: .bottom)

            // Reorder list
            List {
                ForEach(powerModeManager.configurations) { config in
                    HStack(spacing: 12) {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        ZStack {
                            Circle()
                                .fill(Color(NSColor.controlBackgroundColor))
                                .frame(width: 36, height: 36)
                            Text(config.emoji)
                                .font(.system(size: 18))
                        }

                        Text(config.name)
                            .font(.system(size: 14, weight: .medium))

                        Spacer()

                        HStack(spacing: 6) {
                            if config.isDefault {
                                Text("Default")
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.accentColor))
                                    .foregroundColor(.white)
                            }
                            if !config.isEnabled {
                                Text("Disabled")
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color(NSColor.controlBackgroundColor)))
                                    .overlay(
                                        Capsule().stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                                    )
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onMove(perform: powerModeManager.moveConfigurations)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.top, 8)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}


struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 16, weight: .bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 8)
    }
}

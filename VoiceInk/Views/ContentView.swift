import SwiftUI
import SwiftData
import KeyboardShortcuts
import OSLog

// ViewType enum with all cases. Order here is irrelevant to the sidebar —
// the visible order and grouping live in `SidebarSection.allSections`.
enum ViewType: String, CaseIterable, Identifiable {
    case metrics = "Dashboard"
    case transcribeAudio = "Transcribe Audio"
    case history = "History"
    case providers = "Providers"
    case models = "AI Models"
    case enhancement = "Enhancement"
    case powerMode = "Power Mode"
    case permissions = "Permissions"
    case audioInput = "Audio Input"
    case dictionary = "Dictionary"
    case settings = "Settings"
    case license = "VoiceInk Pro"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .metrics: return "gauge.medium"
        case .transcribeAudio: return "waveform.circle.fill"
        case .history: return "doc.text.fill"
        case .providers: return "powerplug.fill"
        case .models: return "brain.head.profile"
        case .enhancement: return "wand.and.stars"
        case .powerMode: return "sparkles.square.fill.on.square"
        case .permissions: return "shield.fill"
        case .audioInput: return "mic.fill"
        case .dictionary: return "character.book.closed.fill"
        case .settings: return "gearshape.fill"
        case .license: return "checkmark.seal.fill"
        }
    }
}

/// Sidebar grouping. Organized by what the user is *doing* — using the
/// app daily, configuring the voice pipeline, granting OS access, or
/// managing their account — so that related items sit together and the
/// most-touched surfaces (Dashboard / History) stay on top.
struct SidebarSection: Identifiable {
    let id: String
    let title: String
    let items: [ViewType]

    static let allSections: [SidebarSection] = [
        SidebarSection(
            id: "activity",
            title: "Activity",
            items: [.metrics, .history, .transcribeAudio]
        ),
        SidebarSection(
            id: "pipeline",
            title: "Voice Pipeline",
            items: [.audioInput, .providers, .models, .enhancement, .powerMode, .dictionary]
        ),
        SidebarSection(
            id: "system",
            title: "System",
            items: [.permissions, .settings]
        ),
        SidebarSection(
            id: "account",
            title: "Account",
            items: [.license]
        ),
    ]
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

struct ContentView: View {
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "ContentView")
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var engine: VoiceInkEngine
    @EnvironmentObject private var whisperModelManager: WhisperModelManager
    @EnvironmentObject private var transcriptionModelManager: TranscriptionModelManager
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @AppStorage("powerModeUIFlag") private var powerModeUIFlag = false
    @State private var selectedView: ViewType? = .metrics
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    @StateObject private var licenseViewModel = LicenseViewModel()

    /// Returns sections with hidden items pruned out. Sections that end
    /// up empty are dropped so we don't render orphan headers. Power Mode
    /// is kept as a disabled discovery entry when its UI flag is off —
    /// the click navigates to Settings instead of opening the disabled
    /// view, see `body`.
    private var visibleSections: [SidebarSection] {
        SidebarSection.allSections.compactMap { section in
            // Every item stays visible — the disabled-entry rendering for
            // Power Mode is handled in the row builder.
            let filtered = section.items
            guard !filtered.isEmpty else { return nil }
            return SidebarSection(id: section.id, title: section.title, items: filtered)
        }
    }

    /// True when this view type is currently routable. Power Mode is the
    /// only conditional case today — disabled until the feature flag is
    /// turned on in Settings.
    private func isRoutable(_ viewType: ViewType) -> Bool {
        if viewType == .powerMode { return powerModeUIFlag }
        return true
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedView) {
                Section {
                    // App Header
                    HStack(spacing: 6) {
                        if let appIcon = NSImage(named: "AppIcon") {
                            Image(nsImage: appIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                                .cornerRadius(8)
                        }

                        Text("VoiceInk")
                            .font(.system(size: 14, weight: .semibold))

                        if case .licensed = licenseViewModel.licenseState {
                            Text("PRO")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.blue)
                                .cornerRadius(4)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }

                ForEach(visibleSections) { section in
                    Section(section.title) {
                        ForEach(section.items) { viewType in
                            if isRoutable(viewType) {
                                NavigationLink(value: viewType) {
                                    SidebarItemView(viewType: viewType)
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                            } else {
                                // Power Mode is gated by a feature flag. Render
                                // a faded, click-through entry that promotes the
                                // toggle in Settings rather than hiding the
                                // feature entirely — users couldn't discover it
                                // before because the sidebar simply didn't list
                                // it.
                                Button(action: { selectedView = .settings }) {
                                    SidebarItemView(viewType: viewType)
                                        .opacity(0.4)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                                .help("Power Mode is disabled. Open Settings → Power Mode to enable.")
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("VoiceInk")
            .navigationSplitViewColumnWidth(210)
        } detail: {
            if let selectedView = selectedView {
                detailView(for: selectedView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle(selectedView.rawValue)
            } else {
                Text("Select a view")
                    .foregroundColor(.secondary)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: 950)
        .frame(minHeight: 730)
        .onAppear {
            logger.notice("ContentView appeared")
        }
        .onDisappear {
            logger.notice("ContentView disappeared")
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToDestination)) { notification in
            if let destination = notification.userInfo?["destination"] as? String {
                logger.notice("navigateToDestination received: \(destination, privacy: .public)")
                switch destination {
                case "Settings":
                    selectedView = .settings
                case "Providers":
                    selectedView = .providers
                case "AI Models":
                    selectedView = .models
                case "VoiceInk Pro":
                    selectedView = .license
                case "History":
                    selectedView = .history
                case "Permissions":
                    selectedView = .permissions
                case "Enhancement":
                    selectedView = .enhancement
                case "Transcribe Audio":
                    selectedView = .transcribeAudio
                case "Power Mode":
                    selectedView = .powerMode
                default:
                    break
                }
            }
        }
    }
    
    @ViewBuilder
    private func detailView(for viewType: ViewType) -> some View {
        switch viewType {
        case .metrics:
            MetricsView()
        case .providers:
            ProvidersView()
        case .models:
            ModelManagementView()
        case .enhancement:
            EnhancementSettingsView()
        case .transcribeAudio:
            AudioTranscribeView()
        case .history:
            InlineHistoryView()
        case .audioInput:
            AudioInputSettingsView()
        case .dictionary:
            DictionarySettingsView(whisperPrompt: whisperModelManager.whisperPrompt)
        case .powerMode:
            PowerModeView()
        case .settings:
            SettingsView()
        case .license:
            LicenseManagementView()
        case .permissions:
            PermissionsView()
        }
    }
}

private struct SidebarItemView: View {
    let viewType: ViewType

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: viewType.icon)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 24, height: 24)

            Text(viewType.rawValue)
                .font(.system(size: 14, weight: .medium))

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
    }
}


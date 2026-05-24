import SwiftUI
import SwiftData
import KeyboardShortcuts
import OSLog

// ViewType enum with all cases. Order here is irrelevant to the sidebar —
// the visible order and grouping live in `SidebarSection.allSections`.
enum ViewType: String, CaseIterable, Identifiable {
    case metrics = "Dashboard"
    case transcribeAudio = "Transcribe File"
    case history = "History"
    case providers = "Providers"
    case models = "AI Models"
    case enhancement = "Enhancement"
    case powerMode = "Profiles"
    case permissions = "Permissions"
    case audioInput = "Audio Input"
    case dictionary = "Dictionary"
    case settings = "Settings"
    /// Repurposed from the upstream "VoiceInk Pro" tab into a neutral
    /// About screen for this fork. Routing key `"VoiceInk Pro"` is kept
    /// for back-compat with stored navigation intents.
    case license = "About"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .metrics: return "gauge.medium"
        case .transcribeAudio: return "waveform.circle.fill"
        case .history: return "doc.text.fill"
        case .providers: return "powerplug.fill"
        case .models: return "brain.head.profile"
        case .enhancement: return "wand.and.stars"
        case .powerMode: return "bolt.fill"
        case .permissions: return "shield.fill"
        case .audioInput: return "mic.fill"
        case .dictionary: return "character.book.closed.fill"
        case .settings: return "gearshape.fill"
        case .license: return "info.circle.fill"
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
            id: "daily",
            title: "Daily",
            items: [.metrics, .history, .transcribeAudio]
        ),
        SidebarSection(
            id: "configure",
            title: "Configure",
            // Profiles first — they're the central paradigm now and act as
            // the entry point that ties everything below together.
            // Enhancement → AI Models → Providers → Audio Input descends
            // from "things you touch often" to "things you touch once".
            items: [.powerMode, .enhancement, .models, .providers, .audioInput]
        ),
        SidebarSection(
            id: "setup",
            title: "Setup",
            // One-time / rarely-touched entries. Rendered as a regular
            // sidebar section (always expanded) so the user can reach
            // permissions and settings without an extra click.
            items: [.permissions, .settings]
        ),
    ]

    /// About lives outside the regular sections and renders as a
    /// bottom-anchored footer entry. It is a single read-only screen the
    /// user visits at most once, so it should not consume a section slot.
    static let footerItem: ViewType = .license
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
    @State private var selectedView: ViewType? = .metrics
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    @StateObject private var licenseViewModel = LicenseViewModel()

    /// Returns sections with hidden items pruned out. Sections that end
    /// up empty are dropped so we don't render orphan headers.
    private var visibleSections: [SidebarSection] {
        SidebarSection.allSections.compactMap { section in
            let filtered = section.items
            guard !filtered.isEmpty else { return nil }
            return SidebarSection(id: section.id, title: section.title, items: filtered)
        }
    }

    /// Every sidebar destination is routable. Power Mode used to gate on
    /// the legacy `powerModeUIFlag`; the feature is now always-on so the
    /// check is gone. Kept as a method so future feature-flag gates can
    /// hook in without restructuring the sidebar body.
    private func isRoutable(_ viewType: ViewType) -> Bool {
        return true
    }

    /// Renders a single sidebar row. Extracted so the Setup section's
    /// DisclosureGroup and the regular sections can share identical row
    /// styling without duplicating the navigation glue.
    @ViewBuilder
    private func sidebarRow(for viewType: ViewType) -> some View {
        NavigationLink(value: viewType) {
            SidebarItemView(viewType: viewType)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        .listRowSeparator(.hidden)
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

                        Text("Open Voice")
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
                            sidebarRow(for: viewType)
                        }
                    }
                }

                // Footer: About sits at the bottom, visually detached from
                // the configuration sections. Single read-only screen with
                // version + credits — does not deserve a section slot.
                Section {
                    sidebarRow(for: SidebarSection.footerItem)
                        .opacity(0.85)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Open Voice")
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
                // Accept both the current label and the legacy
                // "Transcribe Audio" key so notifications stored before
                // the rename still route correctly.
                case "Transcribe File", "Transcribe Audio":
                    selectedView = .transcribeAudio
                case "Profiles", "Power Mode":
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


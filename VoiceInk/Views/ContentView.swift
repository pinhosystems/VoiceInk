import SwiftUI
import SwiftData
import KeyboardShortcuts
import OSLog

// ViewType enum with all cases. Order here is irrelevant to the sidebar —
// the visible order and grouping live in `SidebarSection.allSections`.
enum ViewType: String, CaseIterable, Identifiable {
    case metrics = "Dashboard"
    case transcribeAudio = "File"
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
    case about = "About"

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
        case .about: return "info.circle.fill"
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
            // File-upload transcription used to live here as `.transcribeAudio`,
            // but it's a sporadic action — moved into the History toolbar as
            // an "Upload File…" button. The route itself stays alive at the
            // `.transcribeAudio` view so notifications still resolve.
            items: [.metrics, .history]
        ),
        SidebarSection(
            id: "configure",
            title: "Configure",
            // Pipeline order: signal flows from input device → transcription
            // (providers + AI models) → LLM enhancement → profiles (the
            // routing layer that composes everything above per-app).
            // Profiles is intentionally last because it depends on every
            // step before it.
            items: [.providers, .models, .enhancement, .powerMode]
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
    static let footerItem: ViewType = .about
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
    private let logger = Logger(subsystem: "agabo.dev.voiceink", category: "ContentView")
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var engine: VoiceInkEngine
    @EnvironmentObject private var whisperModelManager: WhisperModelManager
    @EnvironmentObject private var transcriptionModelManager: TranscriptionModelManager
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    // `sidebarSelection` is the List's selection binding. NavigationSplitView
    // clamps it to values that exist as a sidebar row, so it only ever holds
    // a routable sidebar item (or nil while a hidden destination is showing).
    // `activeView` is the detail pane's source of truth and is free of that
    // clamp, so programmatic navigation (file transcription, About, deep
    // links) can reach destinations deliberately kept out of the sidebar.
    // The two stay in sync via the onChange handlers on the split view below.
    @State private var sidebarSelection: ViewType? = .metrics
    @State private var activeView: ViewType = .metrics
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

    /// The full section list — the upstream conversion-funnel reordering
    /// (Providers hoisted while unlicensed) is gone along with licensing.
    private var visibleSections: [SidebarSection] {
        SidebarSection.allSections
    }

    /// Every sidebar destination is routable. Power Mode used to gate on
    /// the legacy `powerModeUIFlag`; the feature is now always-on so the
    /// check is gone. Kept as a method so future feature-flag gates can
    /// hook in without restructuring the sidebar body.
    private func isRoutable(_ viewType: ViewType) -> Bool {
        return true
    }

    /// Whether a destination is present as a row in the sidebar. Used to keep
    /// the sidebar highlight in sync with programmatic navigation: hidden
    /// destinations (file transcription, About) clear the row selection.
    private func isSidebarItem(_ viewType: ViewType) -> Bool {
        SidebarSection.allSections.contains { $0.items.contains(viewType) }
    }

    /// Bottom-anchored About entry. Lives outside the List via
    /// `safeAreaInset(edge:.bottom)` so it occupies the sidebar floor as a
    /// dedicated footer band — a macOS-native pattern (Finder sidebar, Mail
    /// account footer) where ancillary information sits in its own strip
    /// with a thin separator above. The row stays interactive: hover
    /// surfaces a soft accent background, selection paints the accent
    /// fully, and a single tap routes to the About screen.
    @ViewBuilder
    private var aboutFooter: some View {
        AboutFooterRow(
            target: SidebarSection.footerItem,
            appVersion: appVersion,
            isSelected: activeView == SidebarSection.footerItem
        ) {
            activeView = SidebarSection.footerItem
        }
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
            List(selection: $sidebarSelection) {
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
            }
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // About is anchored to the sidebar floor via safeAreaInset
                // so it never competes for attention with the active
                // sections. Smaller font, secondary color, no section
                // header, no list-row chrome — visually clearly subordinate
                // to Setup right above it.
                aboutFooter
            }
            .navigationTitle("VoiceInk")
            .navigationSplitViewColumnWidth(210)
        } detail: {
            detailView(for: activeView)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(activeView.rawValue)
        }
        .navigationSplitViewStyle(.balanced)
        .frame(width: 950)
        .frame(minHeight: 730)
        .onChange(of: sidebarSelection) { _, newValue in
            // User tapped a sidebar row — drive the detail pane from it.
            if let newValue { activeView = newValue }
        }
        .onChange(of: activeView) { _, newValue in
            // Mirror programmatic navigation back onto the sidebar highlight:
            // select the matching row, or clear it when the active view is a
            // destination that has no sidebar row (file transcription, About).
            let desired: ViewType? = isSidebarItem(newValue) ? newValue : nil
            if sidebarSelection != desired { sidebarSelection = desired }
        }
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
                    activeView = .settings
                case "Providers":
                    activeView = .providers
                case "AI Models":
                    activeView = .models
                case "VoiceInk Pro":
                    activeView = .about
                case "History":
                    activeView = .history
                case "Permissions":
                    activeView = .permissions
                case "Enhancement":
                    activeView = .enhancement
                // Accept the current label plus every legacy key — the
                // sidebar has been through "Transcribe Audio" →
                // "Transcribe File" → "file" and notifications stored
                // before each rename should still route correctly.
                case "File", "file", "Transcribe File", "Transcribe Audio":
                    activeView = .transcribeAudio
                case "Profiles", "Power Mode":
                    activeView = .powerMode
                case "Audio Input":
                    activeView = .audioInput
                case "Dictionary":
                    activeView = .dictionary
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
        case .about:
            LicenseManagementView()
        case .permissions:
            PermissionsView()
        }
    }
}

/// Sidebar footer that hosts the About destination. Designed as a
/// dedicated band at the floor of the sidebar (own background,
/// separator above, hover affordance, selection state) instead of a
/// loose `Button` inside `safeAreaInset` so it looks like a finished
/// macOS pattern rather than an after-thought strip.
private struct AboutFooterRow: View {
    let target: ViewType
    let appVersion: String
    let isSelected: Bool
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: target.icon)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(iconForeground)
                    .frame(width: 20, alignment: .center)

                VStack(alignment: .leading, spacing: 1) {
                    Text(target.rawValue)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(primaryForeground)

                    Text("Version \(appVersion)")
                        .font(.system(size: 10))
                        .foregroundStyle(secondaryForeground)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(chevronForeground)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .background(rowBackground)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
        .overlay(Divider().opacity(0.65), alignment: .top)
    }

    private var rowBackground: Color {
        if isSelected { return Color.accentColor.opacity(0.18) }
        if isHovering { return Color.primary.opacity(0.05) }
        return Color.clear
    }

    private var primaryForeground: Color {
        isSelected ? .primary : .primary
    }

    private var secondaryForeground: Color {
        .secondary
    }

    private var iconForeground: Color {
        isSelected ? .accentColor : .secondary
    }

    private var chevronForeground: Color {
        isHovering || isSelected ? .secondary : .secondary.opacity(0.35)
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


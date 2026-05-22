import SwiftUI

/// Providers tab: the single source of truth for credential and
/// installation state across every provider VoiceInk integrates with —
/// local on-device engines (Whisper, Parakeet, Native Apple, Ollama,
/// Local CLI), cloud APIs (OpenAI, xAI, Groq, etc.), and the Custom
/// OpenAI-compatible escape hatch.
///
/// The visual language mirrors `ModelManagementView`: a header section, a
/// pill-style filter switcher (All / Local / Cloud / Custom), and a
/// vertically stacked list of cards — one per provider. Each card carries
/// the provider's full configuration inline; there is no separate detail
/// pane. Local providers expose their model list with download/delete
/// inline, cloud providers expose API-key entry + capability-scoped
/// settings, and Custom exposes a base URL + model + key form.
struct ProvidersView: View {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var catalog: ProviderCatalog

    @State private var selectedFilter: ProviderFilter = .all

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                summaryCard
                filterPills
                providersList
            }
            .padding(40)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Providers")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("\(configuredCount) of \(catalog.entries.count) providers configured")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(isSelected: false))
        .cornerRadius(10)
    }

    private var summaryCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.accentColor)
                .font(.system(size: 14, weight: .semibold))
            VStack(alignment: .leading, spacing: 4) {
                Text("One place to manage every backend VoiceInk can talk to.")
                    .font(.system(size: 13, weight: .medium))
                Text("Pick the active STT model in AI Models, the active LLM in Enhancement. Both only show providers configured here.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08))
        .cornerRadius(8)
    }

    private var filterPills: some View {
        HStack(spacing: 12) {
            ForEach(ProviderFilter.allCases) { filter in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedFilter = filter
                    }
                } label: {
                    Text(filter.displayName)
                        .font(.system(size: 14, weight: selectedFilter == filter ? .semibold : .medium))
                        .foregroundColor(selectedFilter == filter ? .primary : .primary.opacity(0.7))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(CardBackground(isSelected: selectedFilter == filter, cornerRadius: 22))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.bottom, 4)
    }

    private var providersList: some View {
        VStack(spacing: 14) {
            ForEach(filteredEntries) { entry in
                ProviderCardView(entry: entry)
            }
        }
    }

    private var filteredEntries: [ProviderEntry] {
        switch selectedFilter {
        case .all:    return catalog.entries
        case .local:  return catalog.providers(in: .local)
        case .cloud:  return catalog.providers(in: .cloud)
        case .custom: return catalog.providers(in: .custom)
        }
    }

    private var configuredCount: Int {
        _ = catalog.configurationRevision
        return catalog.entries.filter { catalog.isConfigured($0) }.count
    }
}

enum ProviderFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case local = "Local"
    case cloud = "Cloud"
    case custom = "Custom"

    var id: String { rawValue }
    var displayName: String { rawValue }
}

// MARK: - Shared capability badge

struct CapabilityBadge: View {
    let capability: ProviderCapability
    var compact: Bool = false

    var body: some View {
        Text(capability.displayName)
            .font(.system(size: compact ? 9 : 10, weight: .semibold))
            .padding(.horizontal, compact ? 5 : 6)
            .padding(.vertical, compact ? 1 : 2)
            .background(color.opacity(0.18))
            .foregroundColor(color)
            .cornerRadius(compact ? 3 : 4)
    }

    private var color: Color {
        switch capability {
        case .stt: return .blue
        case .llm: return .purple
        }
    }
}

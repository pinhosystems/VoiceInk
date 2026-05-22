import SwiftUI

/// Providers tab: the single source of truth for credential and
/// installation state across every provider VoiceInk integrates with —
/// local on-device engines (Whisper, Parakeet, Native Apple, Ollama,
/// Local CLI), cloud APIs (OpenAI, xAI, Groq, etc.), and the Custom
/// OpenAI-compatible escape hatch.
///
/// The visual language mirrors `ModelManagementView`: a header section, a
/// pill-style filter switcher (All / Local / Cloud / Custom), a search
/// field for name lookup, and a vertically stacked list of accordion
/// cards — one per provider. Cards start collapsed so the page stays
/// scannable; the user expands the ones they care about.
struct ProvidersView: View {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var catalog: ProviderCatalog

    @State private var selectedFilter: ProviderFilter = .all
    @State private var searchText: String = ""
    @State private var expandedIDs: Set<ProviderID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                summaryCard
                filtersRow
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

    private var filtersRow: some View {
        VStack(spacing: 12) {
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

                expandCollapseButtons
            }

            searchField
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 13))
            TextField("Filter by name…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private var expandCollapseButtons: some View {
        HStack(spacing: 6) {
            Button("Expand all") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedIDs = Set(filteredEntries.map { $0.id })
                }
            }
            .controlSize(.small)
            .buttonStyle(.borderless)
            .disabled(filteredEntries.isEmpty)

            Button("Collapse all") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedIDs.removeAll()
                }
            }
            .controlSize(.small)
            .buttonStyle(.borderless)
            .disabled(expandedIDs.isEmpty)
        }
        .font(.system(size: 12))
    }

    @ViewBuilder
    private var providersList: some View {
        if filteredEntries.isEmpty {
            emptyState
        } else {
            VStack(spacing: 12) {
                ForEach(filteredEntries) { entry in
                    ProviderCardView(
                        entry: entry,
                        isExpanded: expandedIDs.contains(entry.id),
                        onToggleExpand: { toggleExpanded(entry.id) }
                    )
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.6))
            Text("No providers match your filter.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            if !searchText.isEmpty {
                Button("Clear search") { searchText = "" }
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(CardBackground(isSelected: false))
        .cornerRadius(10)
    }

    private var filteredEntries: [ProviderEntry] {
        let pool: [ProviderEntry]
        switch selectedFilter {
        case .all:    pool = catalog.entries
        case .local:  pool = catalog.providers(in: .local)
        case .cloud:  pool = catalog.providers(in: .cloud)
        case .custom: pool = catalog.providers(in: .custom)
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return pool }
        return pool.filter { $0.displayName.localizedCaseInsensitiveContains(trimmed) }
    }

    private var configuredCount: Int {
        _ = catalog.configurationRevision
        return catalog.entries.filter { catalog.isConfigured($0) }.count
    }

    private func toggleExpanded(_ id: ProviderID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedIDs.contains(id) {
                expandedIDs.remove(id)
            } else {
                expandedIDs.insert(id)
            }
        }
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

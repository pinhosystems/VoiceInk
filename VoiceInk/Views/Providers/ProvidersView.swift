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
    @ObservedObject private var customManager = CustomProviderManager.shared

    @State private var selectedFilter: ProviderFilter = .all
    @State private var searchText: String = ""
    @State private var capabilityFilter: Set<ProviderCapability> = []
    @State private var statusFilter: ProviderStatusFilter = .all
    @State private var expandedIDs: Set<ProviderID> = []
    @State private var expandedCustomIDs: Set<UUID> = []

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
            Text("\(configuredCount) of \(totalProviderCount) providers configured")
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

            HStack(spacing: 10) {
                searchField
                capabilityChips
                statusChips
            }
        }
    }

    private var capabilityChips: some View {
        HStack(spacing: 6) {
            ForEach(ProviderCapability.allCases.sorted(), id: \.self) { capability in
                CapabilityFilterChip(
                    capability: capability,
                    isOn: capabilityFilter.contains(capability),
                    toggle: { toggleCapability(capability) }
                )
            }
        }
    }

    private var statusChips: some View {
        HStack(spacing: 6) {
            StatusFilterChip(
                label: "Configured",
                systemImage: "checkmark.circle.fill",
                tint: .green,
                isOn: statusFilter == .configured,
                toggle: { toggleStatus(.configured) }
            )
            StatusFilterChip(
                label: "Needs setup",
                systemImage: "exclamationmark.circle.fill",
                tint: .orange,
                isOn: statusFilter == .needsSetup,
                toggle: { toggleStatus(.needsSetup) }
            )
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
                    expandedCustomIDs = Set(filteredCustomProviders.map { $0.id })
                }
            }
            .controlSize(.small)
            .buttonStyle(.borderless)
            .disabled(filteredEntries.isEmpty && filteredCustomProviders.isEmpty)

            Button("Collapse all") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedIDs.removeAll()
                    expandedCustomIDs.removeAll()
                }
            }
            .controlSize(.small)
            .buttonStyle(.borderless)
            .disabled(expandedIDs.isEmpty && expandedCustomIDs.isEmpty)
        }
        .font(.system(size: 12))
    }

    @ViewBuilder
    private var providersList: some View {
        if filteredEntries.isEmpty && filteredCustomProviders.isEmpty && !shouldShowAddCustom {
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
                ForEach(filteredCustomProviders) { provider in
                    CustomProviderCardView(
                        provider: provider,
                        isExpanded: expandedCustomIDs.contains(provider.id),
                        onToggleExpand: { toggleCustomExpanded(provider.id) }
                    )
                }
                if shouldShowAddCustom {
                    addCustomButton
                }
            }
        }
    }

    private var addCustomButton: some View {
        Button {
            addCustomProvider()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                Text("Add custom provider")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CardBackground(isSelected: false))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
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
        case .custom: pool = []  // statics never live under Custom
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return pool.filter { entry in
            matchesSearch(entry.displayName, trimmed: trimmed)
                && matchesCapability(entry.capabilities)
                && matchesStatus(isConfigured: catalog.isConfigured(entry))
        }
    }

    private var filteredCustomProviders: [CustomProvider] {
        guard selectedFilter == .all || selectedFilter == .custom else { return [] }
        let pool = customManager.providers
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return pool.filter { provider in
            matchesSearch(provider.name, trimmed: trimmed)
                && matchesCapability(provider.capabilities)
                && matchesStatus(isConfigured: isCustomConfigured(provider))
        }
    }

    private func isCustomConfigured(_ provider: CustomProvider) -> Bool {
        _ = catalog.configurationRevision
        guard provider.offersSTT || provider.offersLLM else { return false }
        return APIKeyManager.shared.getCustomModelAPIKey(forModelId: provider.id) != nil
    }

    private func matchesSearch(_ name: String, trimmed: String) -> Bool {
        guard !trimmed.isEmpty else { return true }
        return name.localizedCaseInsensitiveContains(trimmed)
    }

    /// `true` when the provider passes the capability filter. Nothing
    /// selected = no constraint, show everyone. One or more chips selected =
    /// AND filter: the provider must offer every selected capability. Both
    /// chips on therefore narrows to providers that do both STT and LLM.
    private func matchesCapability(_ capabilities: Set<ProviderCapability>) -> Bool {
        let active = capabilityFilter
        if active.isEmpty { return true }
        return capabilities.isSuperset(of: active)
    }

    private func toggleCapability(_ capability: ProviderCapability) {
        if capabilityFilter.contains(capability) {
            capabilityFilter.remove(capability)
        } else {
            capabilityFilter.insert(capability)
        }
    }

    /// Three-state status filter behind two chips. Clicking the active chip
    /// turns it off (back to "all"); clicking the other chip swaps the
    /// selection. Both chips off means "no constraint".
    private func matchesStatus(isConfigured: Bool) -> Bool {
        switch statusFilter {
        case .all:        return true
        case .configured: return isConfigured
        case .needsSetup: return !isConfigured
        }
    }

    private func toggleStatus(_ option: ProviderStatusFilter) {
        statusFilter = (statusFilter == option) ? .all : option
    }

    private var shouldShowAddCustom: Bool {
        guard selectedFilter == .all || selectedFilter == .custom else { return false }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty
    }

    private var configuredCount: Int {
        _ = catalog.configurationRevision
        let staticCount = catalog.entries.filter { catalog.isConfigured($0) }.count
        let customCount = customManager.providers.filter { provider in
            APIKeyManager.shared.getCustomModelAPIKey(forModelId: provider.id) != nil &&
            (provider.offersSTT || provider.offersLLM)
        }.count
        return staticCount + customCount
    }

    private var totalProviderCount: Int {
        catalog.entries.count + customManager.providers.count
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

    private func toggleCustomExpanded(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedCustomIDs.contains(id) {
                expandedCustomIDs.remove(id)
            } else {
                expandedCustomIDs.insert(id)
            }
        }
    }

    private func addCustomProvider() {
        let newProvider = CustomProvider(
            name: "Untitled custom",
            offersSTT: false,
            offersLLM: true,
            llmEndpointURL: "",
            llmModelName: ""
        )
        CustomProviderManager.shared.add(newProvider)
        expandedCustomIDs.insert(newProvider.id)
        catalog.markChanged()
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

enum ProviderStatusFilter {
    case all
    case configured
    case needsSetup
}

// MARK: - Capability filter chip

private struct CapabilityFilterChip: View {
    let capability: ProviderCapability
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 4) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 11, weight: .semibold))
                Text(capability.displayName)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundColor(isOn ? color : .secondary)
            .background(
                Capsule()
                    .fill(isOn ? color.opacity(0.16) : Color.secondary.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(isOn ? color.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(isOn ? "Showing only \(capability.displayName)-capable providers" : "Filter to \(capability.displayName)-capable providers")
    }

    private var color: Color {
        switch capability {
        case .stt: return .blue
        case .llm: return .purple
        }
    }
}

// MARK: - Status filter chip

private struct StatusFilterChip: View {
    let label: String
    let systemImage: String
    let tint: Color
    let isOn: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundColor(isOn ? tint : .secondary)
            .background(
                Capsule()
                    .fill(isOn ? tint.opacity(0.16) : Color.secondary.opacity(0.08))
            )
            .overlay(
                Capsule()
                    .stroke(isOn ? tint.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .help(isOn ? "Showing only \(label.lowercased()) providers" : "Filter to \(label.lowercased()) providers")
    }
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

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
    @ObservedObject private var localCLIManager = LocalCLIProviderManager.shared

    @State private var selectedFilter: ProviderFilter = .all
    @State private var searchText: String = ""
    @State private var capabilityFilter: Set<ProviderCapability> = []
    @State private var statusFilter: ProviderStatusFilter = .all
    @State private var expandedIDs: Set<ProviderID> = []
    @State private var expandedCustomIDs: Set<UUID> = []
    @State private var expandedLocalCLIIDs: Set<UUID> = []
    @State private var scrollTargetID: String?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    summaryCard
                    filtersRow
                    providersList
                }
                .padding(40)
            }
            .onChange(of: scrollTargetID) { _, target in
                guard let id = target else { return }
                // Two-stage scroll: first hop without animation locks the
                // target near the top once the new card has been laid out,
                // then a brief animated nudge highlights it.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    proxy.scrollTo(id, anchor: .top)
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(id, anchor: .top)
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        scrollTargetID = nil
                    }
                }
            }
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
            Text("Pick the active STT model in AI Models, the active LLM in Enhancement — both only list providers configured here.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
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
            addProviderMenu

            Button("Expand all") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedIDs = Set(filteredEntries.map { $0.id })
                    expandedCustomIDs = Set(filteredCustomProviders.map { $0.id })
                    expandedLocalCLIIDs = Set(filteredLocalCLIProviders.map { $0.id })
                }
            }
            .controlSize(.small)
            .buttonStyle(.borderless)
            .disabled(filteredEntries.isEmpty && filteredCustomProviders.isEmpty && filteredLocalCLIProviders.isEmpty)

            Button("Collapse all") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedIDs.removeAll()
                    expandedCustomIDs.removeAll()
                    expandedLocalCLIIDs.removeAll()
                }
            }
            .controlSize(.small)
            .buttonStyle(.borderless)
            .disabled(expandedIDs.isEmpty && expandedCustomIDs.isEmpty && expandedLocalCLIIDs.isEmpty)
        }
        .font(.system(size: 12))
    }

    /// Single "Add" menu surfacing both user-defined provider types up at
    /// the filter row, so the action is reachable without scrolling past
    /// the entire static catalog first.
    private var addProviderMenu: some View {
        Menu {
            Button {
                addCustomProvider()
            } label: {
                Label("Custom provider", systemImage: "gearshape.2.fill")
            }
            Button {
                addLocalCLIProvider()
            } label: {
                Label("Local CLI", systemImage: "terminal")
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .semibold))
                Text("Add")
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.accentColor.opacity(0.18)))
            .foregroundColor(.accentColor)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    private var providersList: some View {
        if filteredEntries.isEmpty && filteredCustomProviders.isEmpty && filteredLocalCLIProviders.isEmpty {
            emptyState
        } else {
            VStack(spacing: 12) {
                ForEach(filteredEntries) { entry in
                    ProviderCardView(
                        entry: entry,
                        isExpanded: expandedIDs.contains(entry.id),
                        onToggleExpand: { toggleExpanded(entry.id) }
                    )
                    .id(entry.id.rawValue)
                }
                ForEach(filteredLocalCLIProviders) { provider in
                    LocalCLIProviderCardView(
                        provider: provider,
                        isExpanded: expandedLocalCLIIDs.contains(provider.id),
                        onToggleExpand: { toggleLocalCLIExpanded(provider.id) }
                    )
                    .id(provider.id.uuidString)
                }
                ForEach(filteredCustomProviders) { provider in
                    CustomProviderCardView(
                        provider: provider,
                        isExpanded: expandedCustomIDs.contains(provider.id),
                        onToggleExpand: { toggleCustomExpanded(provider.id) }
                    )
                    .id(provider.id.uuidString)
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

    private var filteredLocalCLIProviders: [LocalCLIProvider] {
        // Local CLI providers live under the Local category; they are LLM-
        // capable and never STT, so capability + category filters apply.
        guard selectedFilter == .all || selectedFilter == .local else { return [] }
        let pool = localCLIManager.providers
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return pool.filter { provider in
            matchesSearch(provider.name, trimmed: trimmed)
                && matchesCapability([.llm])
                && matchesStatus(isConfigured: provider.isConfigured)
        }
    }

    private func isCustomConfigured(_ provider: CustomProvider) -> Bool {
        _ = catalog.configurationRevision
        guard APIKeyManager.shared.getCustomModelAPIKey(forModelId: provider.id) != nil else { return false }
        let usable = provider.usableCapabilities
        guard !usable.isEmpty else { return false }
        if provider.offersSTT && !provider.hasUsableSTT { return false }
        if provider.offersLLM && !provider.hasUsableLLM { return false }
        return true
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

    private var configuredCount: Int {
        _ = catalog.configurationRevision
        let staticCount = catalog.entries.filter { catalog.isConfigured($0) }.count
        let customCount = customManager.providers.filter { isCustomConfigured($0) }.count
        let cliCount = localCLIManager.configuredProviders.count
        return staticCount + customCount + cliCount
    }

    private var totalProviderCount: Int {
        catalog.entries.count + customManager.providers.count + localCLIManager.providers.count
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

    private func toggleLocalCLIExpanded(_ id: UUID) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedLocalCLIIDs.contains(id) {
                expandedLocalCLIIDs.remove(id)
            } else {
                expandedLocalCLIIDs.insert(id)
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
        revealNewCard(category: .custom, scrollID: newProvider.id.uuidString)
        catalog.markChanged()
    }

    private func addLocalCLIProvider() {
        let newProvider = LocalCLIProvider(name: "Untitled CLI")
        LocalCLIProviderManager.shared.add(newProvider)
        expandedLocalCLIIDs.insert(newProvider.id)
        revealNewCard(category: .local, scrollID: newProvider.id.uuidString)
        catalog.markChanged()
    }

    /// Resets any filter that could hide a freshly-added card and queues a
    /// scroll-to so the new entry shows up on screen instead of being
    /// appended invisibly below the static catalog.
    ///
    /// Why every filter is reset: a new card always starts as "Needs
    /// setup", with whatever capabilities the seed defaults imply
    /// (offersLLM=true / offersSTT=false for Custom; LLM only for Local
    /// CLI). The status chip "Configured", the capability chip "STT", or
    /// an unrelated search query would silently hide the new row right
    /// after creation — surprising and easy to read as a bug.
    private func revealNewCard(category: ProviderCategory, scrollID: String) {
        switch category {
        case .custom: selectedFilter = .custom
        case .local:  selectedFilter = .local
        case .cloud:  selectedFilter = .cloud
        }
        searchText = ""
        capabilityFilter.removeAll()
        statusFilter = .all
        scrollTargetID = scrollID
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

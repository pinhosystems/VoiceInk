import SwiftUI

/// Top-level Providers tab: lists every provider VoiceInk integrates with on
/// the left, and shows credential entry + per-modality settings for the
/// selected provider on the right.
///
/// This view is the single source of truth for credential management.
/// Active-model picking (which STT model to use, which LLM model to enhance
/// with) remains in the "AI Models" and "Enhancement" tabs respectively —
/// those tabs only pick from providers configured here.
struct ProvidersView: View {
    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var catalog: ProviderCatalog
    @State private var selectedID: ProviderID?

    var body: some View {
        HSplitView {
            providerList
                .frame(minWidth: 240, idealWidth: 260, maxWidth: 320)
            detailPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            if selectedID == nil {
                selectedID = catalog.entries.first?.id
            }
        }
    }

    private var providerList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(catalog.entries) { entry in
                    Button {
                        selectedID = entry.id
                    } label: {
                        ProviderRow(
                            entry: entry,
                            isSelected: entry.id == selectedID,
                            isConfigured: catalog.isConfigured(entry)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    @ViewBuilder
    private var detailPane: some View {
        if let id = selectedID, let entry = catalog.entry(for: id) {
            ProviderDetailView(entry: entry)
                .id(id)
        } else {
            Text("Select a provider")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct ProviderRow: View {
    let entry: ProviderEntry
    let isSelected: Bool
    let isConfigured: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isConfigured ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isConfigured ? .green : .secondary)
                .font(.system(size: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                HStack(spacing: 4) {
                    ForEach(entry.capabilities.sorted(), id: \.self) { cap in
                        CapabilityBadge(capability: cap, compact: true)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
    }
}

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

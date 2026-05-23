import SwiftUI
import LLMkit

/// A single provider card in the Providers tab. Accordion-style: the
/// header strip is always visible and clicking it toggles the body's
/// visibility. The body carries the credential entry plus any
/// capability-scoped tuning knobs (currently just xAI's STT settings).
///
/// The "active LLM is picked in Enhancement" hint that used to live
/// inside every LLM-capable card was moved to the page-level summary
/// banner in `ProvidersView`, since repeating it ~17 times added noise.
struct ProviderCardView: View {
    let entry: ProviderEntry
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var catalog: ProviderCatalog

    private var isConfigured: Bool { catalog.isConfigured(entry) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerStrip
                .contentShape(Rectangle())
                .onTapGesture { onToggleExpand() }
            if isExpanded {
                Divider().padding(.top, 14)
                VStack(alignment: .leading, spacing: 14) {
                    credentialBody
                    if entry.capabilities.contains(.stt) && hasProviderSpecificSTTSettings {
                        Divider()
                        sttSettingsBlock
                    }
                }
                .padding(.top, 14)
                .transition(
                    .asymmetric(
                        insertion: .opacity.animation(.easeInOut(duration: 0.22).delay(0.05)),
                        removal: .opacity.animation(.easeInOut(duration: 0.12))
                    )
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(isSelected: false))
        .cornerRadius(12)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: isExpanded)
    }

    private var headerStrip: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: entry.iconSystemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.displayName)
                        .font(.title3.bold())
                    ForEach(entry.capabilities.sorted(), id: \.self) { cap in
                        CapabilityBadge(capability: cap)
                    }
                    Spacer()
                    statusPill
                    chevron
                }
                Text(entry.summary)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isConfigured ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(isConfigured ? "Configured" : "Needs setup")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background((isConfigured ? Color.green : Color.orange).opacity(0.12))
        .cornerRadius(10)
    }

    private var chevron: some View {
        Image(systemName: "chevron.down")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary)
            .rotationEffect(.degrees(isExpanded ? 180 : 0))
            .padding(6)
            .background(Circle().fill(Color.secondary.opacity(0.08)))
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }

    @ViewBuilder
    private var credentialBody: some View {
        switch entry.credentialKind {
        case .apiKey:
            APIKeyCredentialView(entry: entry)
        case .baseURL:
            OllamaCredentialView()
        case .commandTemplate:
            LocalCLICredentialView()
        case .baseURLAndModel:
            CustomProviderCredentialView()
        case .localModels:
            LocalModelsCredentialView(entry: entry)
        case .builtIn:
            BuiltInProviderInfoView(entry: entry)
        }
    }

    @ViewBuilder
    private var sttSettingsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(title: "STT settings", systemImage: "waveform")
            switch entry.id {
            case .xai:
                XAIAdvancedSettingsView()
            default:
                EmptyView()
            }
        }
    }

    private func sectionHeader(title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }

    private var hasProviderSpecificSTTSettings: Bool {
        entry.id == .xai
    }
}

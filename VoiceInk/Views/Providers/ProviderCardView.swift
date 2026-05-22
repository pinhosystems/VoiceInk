import SwiftUI
import LLMkit

/// A single provider card in the Providers tab. Renders inline:
///   - a header strip with icon, name, summary, capability badges and a
///     configured/needs-setup status pill
///   - a credential body that switches on `entry.credentialKind` (API key,
///     base URL, command template, base URL + model, local models, or
///     built-in / no setup)
///   - an STT settings strip if the provider offers STT and there are
///     provider-scoped tuning knobs (currently xAI only)
///
/// Cards never collapse: matching the visual rhythm of `ModelCardView`
/// from the AI Models tab where every model is laid out inline.
struct ProviderCardView: View {
    let entry: ProviderEntry

    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var catalog: ProviderCatalog

    private var isConfigured: Bool { catalog.isConfigured(entry) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            headerStrip
            Divider()
            credentialBody
            if entry.capabilities.contains(.stt) && hasProviderSpecificSTTSettings {
                Divider()
                sttSettingsBlock
            }
            if entry.capabilities.contains(.llm) {
                Divider()
                llmHint
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(isSelected: false))
        .cornerRadius(12)
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

    private var llmHint: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionHeader(title: "LLM enhancement", systemImage: "bubble.left.and.bubble.right")
            Text("Active LLM model is selected in the Enhancement tab from providers configured here.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
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

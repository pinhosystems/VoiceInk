import SwiftUI

/// Accordion card for a single user-defined `LocalCLIProvider`. Mirrors
/// `CustomProviderCardView`: header with capability badge + status pill,
/// expandable body with inline editor. Every field writes back through
/// `LocalCLIProviderManager` so AIService and the Enhancement picker see
/// changes immediately.
struct LocalCLIProviderCardView: View {
    let provider: LocalCLIProvider
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @EnvironmentObject private var aiService: AIService
    @EnvironmentObject private var catalog: ProviderCatalog

    @State private var draft: LocalCLIProvider
    @State private var confirmDelete = false

    private static let timeoutOptions: [Double] = [15, 30, 45, 60, 90, 120, 180, 300]

    init(provider: LocalCLIProvider, isExpanded: Bool, onToggleExpand: @escaping () -> Void) {
        self.provider = provider
        self.isExpanded = isExpanded
        self.onToggleExpand = onToggleExpand
        _draft = State(initialValue: provider)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerStrip
                .contentShape(Rectangle())
                .onTapGesture { onToggleExpand() }
            if isExpanded {
                Divider().padding(.top, 14)
                editorBody
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
        .alert("Delete Local CLI provider?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive) {
                LocalCLIProviderManager.shared.remove(id: provider.id)
                if aiService.selectedLocalCLIProviderID == provider.id {
                    aiService.selectedLocalCLIProviderID = nil
                }
                catalog.markChanged()
                NotificationCenter.default.post(name: .aiProviderKeyChanged, object: nil)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("\(provider.name) and its command template will be removed. If it was the active CLI, the enhancement picker will fall back to the next configured one.")
        }
    }

    private var headerStrip: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "terminal")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 36, height: 36)
                .background(Color.accentColor.opacity(0.12))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(provider.name.isEmpty ? "Unnamed CLI" : provider.name)
                        .font(.title3.bold())
                    CapabilityBadge(capability: .llm)
                    Spacer()
                    statusPill
                    chevron
                }
                Text(provider.commandTemplate.isEmpty
                     ? "Shell command that runs on every enhancement."
                     : "Runs: \(provider.commandTemplate)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
    }

    private var statusPill: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(provider.isConfigured ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(provider.isConfigured ? "Configured" : "Needs setup")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background((provider.isConfigured ? Color.green : Color.orange).opacity(0.12))
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

    private var editorBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            identityBlock
            commandBlock
            timeoutBlock
            deleteFooter
        }
    }

    private var identityBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Identity", systemImage: "person.text.rectangle")
            TextField("", text: $draft.name, prompt: Text("e.g. Claude CLI"))
                .textFieldStyle(.roundedBorder)
                .onChange(of: draft.name) { _, _ in persist() }
        }
    }

    private var commandBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("Command", systemImage: "terminal")
                Spacer()
                Menu("Load template") {
                    ForEach(LocalCLITemplate.allCases) { template in
                        Button(template.displayName) {
                            draft.commandTemplate = template.commandTemplate
                            persist()
                        }
                    }
                }
            }
            TextEditor(text: $draft.commandTemplate)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 100)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)
                )
                .onChange(of: draft.commandTemplate) { _, _ in persist() }
            Text("Environment variables: VOICEINK_SYSTEM_PROMPT, VOICEINK_USER_PROMPT, VOICEINK_FULL_PROMPT (also written to stdin).")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var timeoutBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Timeout", systemImage: "clock")
            Picker("", selection: $draft.timeoutSeconds) {
                ForEach(Self.timeoutOptions, id: \.self) { Text("\(Int($0))s").tag($0) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .onChange(of: draft.timeoutSeconds) { _, _ in persist() }
        }
    }

    private var deleteFooter: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            HStack {
                Spacer()
                Button("Delete provider", role: .destructive) { confirmDelete = true }
                    .controlSize(.small)
            }
            .padding(.top, 10)
        }
    }

    private func sectionTitle(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
        }
    }

    private func persist() {
        LocalCLIProviderManager.shared.update(draft)
        catalog.markChanged()
    }
}

import SwiftUI
import SwiftData

/// Shared sheet used by both the Vocabulary tab and the Word Replacements tab.
/// The user picks a locale/template first; the sheet shows a preview (total
/// available, how many will be inserted, how many already exist) and commits
/// the batch on confirm. The bulk-add is decoupled from the active STT
/// language — the user can seed any supported locale regardless of which
/// language the recognizer is currently set to.
struct BulkAddTemplateSheet: View {
    enum Kind {
        case vocabulary
        case abbreviations

        var navigationTitle: String {
            switch self {
            case .vocabulary: return "Add Vocabulary from Template"
            case .abbreviations: return "Add Abbreviations from Template"
            }
        }

        var subtitle: String {
            switch self {
            case .vocabulary:
                return "Pick a language or region to insert its curated vocabulary terms. Entries already in your dictionary are skipped."
            case .abbreviations:
                return "Pick a language or region to insert its curated abbreviations and chat-style shortcuts. Triggers that already exist are skipped."
            }
        }

        var confirmLabel: String {
            switch self {
            case .vocabulary: return "Add Vocabulary"
            case .abbreviations: return "Add Abbreviations"
            }
        }

        var pickerLabel: String { "Language / region" }

        var previewTotalLabel: String {
            switch self {
            case .vocabulary: return "vocabulary terms"
            case .abbreviations: return "abbreviations"
            }
        }
    }

    let kind: Kind
    let templates: [BulkTemplate]
    let preview: (BulkTemplate) -> (newCount: Int, skippedCount: Int)
    let onConfirm: (BulkTemplate) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTemplate: BulkTemplate?
    @State private var showContents = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            content
        }
        .frame(width: 480, height: 460)
        .onAppear {
            if selectedTemplate == nil {
                selectedTemplate = templates.first
            }
        }
    }

    private var header: some View {
        HStack {
            Button("Cancel", role: .cancel) { dismiss() }
                .buttonStyle(.borderless)
                .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            Text(kind.navigationTitle)
                .font(.headline)

            Spacer()

            Button(kind.confirmLabel) {
                if let template = selectedTemplate {
                    onConfirm(template)
                }
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(selectedTemplate == nil || confirmDisabled)
            .keyboardShortcut(.return, modifiers: [])
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(CardBackground(isSelected: false))
    }

    private var confirmDisabled: Bool {
        guard let template = selectedTemplate else { return true }
        let (newCount, _) = preview(template)
        return newCount == 0
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(kind.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal)
                    .padding(.top, 16)

                pickerSection
                    .padding(.horizontal)

                if let template = selectedTemplate {
                    previewSection(for: template)
                        .padding(.horizontal)
                }
            }
            .padding(.bottom, 16)
        }
    }

    private var pickerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kind.pickerLabel)
                .font(.headline)
            Picker("", selection: $selectedTemplate) {
                ForEach(templates) { template in
                    Text(template.displayName).tag(Optional(template))
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func previewSection(for template: BulkTemplate) -> some View {
        let stats = preview(template)
        let total: Int = {
            switch kind {
            case .vocabulary: return template.vocabularyTerms.count
            case .abbreviations: return template.wordReplacements.count
            }
        }()

        return VStack(alignment: .leading, spacing: 10) {
            Text("Preview")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Label("\(total) \(kind.previewTotalLabel) in this template", systemImage: "tray.full")
                    .foregroundColor(.secondary)
                Label("\(stats.newCount) will be added", systemImage: "plus.circle.fill")
                    .foregroundColor(stats.newCount > 0 ? .accentColor : .secondary)
                Label("\(stats.skippedCount) already in your dictionary (skipped)", systemImage: "checkmark.circle")
                    .foregroundColor(.secondary)
            }
            .font(.callout)

            DisclosureGroup("See what's inside", isExpanded: $showContents) {
                contentsList(for: template)
                    .padding(.top, 4)
            }
            .font(.callout)
        }
    }

    @ViewBuilder
    private func contentsList(for template: BulkTemplate) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                switch kind {
                case .vocabulary:
                    ForEach(template.vocabularyTerms, id: \.self) { term in
                        Text(term)
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .abbreviations:
                    ForEach(template.wordReplacements, id: \.original) { pair in
                        HStack(spacing: 8) {
                            Text(pair.original)
                                .font(.callout)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(pair.replacement)
                                .font(.callout)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: 160)
    }
}

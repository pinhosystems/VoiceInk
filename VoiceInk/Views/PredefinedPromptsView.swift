import SwiftUI

struct PredefinedPromptsView: View {
    let onSelect: (TemplatePrompt) -> Void
    
    private let columns: [GridItem] = Array(repeating: GridItem(.flexible(), spacing: 18), count: 2)
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(PromptTemplates.all, id: \.title) { template in
                    PredefinedTemplateButton(prompt: template) {
                        onSelect(template)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(minWidth: 410, idealWidth: 520, maxWidth: 570, maxHeight: 440)
    }
}

struct PredefinedTemplateButton: View {
    let prompt: TemplatePrompt
    let action: () -> Void
    @State private var isShowingText = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(NSColor.unemphasizedSelectedTextBackgroundColor))
                        .frame(width: 42, height: 42)
                        .overlay(
                            Image(systemName: prompt.icon)
                                .font(.system(size: 19, weight: .medium))
                                .foregroundColor(Color(NSColor.labelColor))
                        )
                    
                    Text(prompt.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 22)
                }
                
                Text(prompt.description)
                    .font(.system(size: 12))
                    .foregroundColor(Color(NSColor.secondaryLabelColor))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(cardBackground)
            .overlay(cardStroke)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: cardShadowColor, radius: 6, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topTrailing) { textPreviewButton }
    }

    /// The card itself clones the template; this shows what it actually
    /// contains first, so the text is not a black box until after cloning.
    private var textPreviewButton: some View {
        Button {
            isShowingText.toggle()
        } label: {
            Image(systemName: "eye")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, 8)
        .padding(.top, 8)
        .help("Show the prompt text")
        .popover(isPresented: $isShowingText, arrowEdge: .trailing) {
            ScrollView {
                Text(prompt.promptText)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(width: 420, height: 320)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(NSColor.controlBackgroundColor))
    }
    
    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: [
                        Color(NSColor.separatorColor).opacity(0.35),
                        Color(NSColor.separatorColor).opacity(0.15)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    private var cardShadowColor: Color {
        Color(NSColor.shadowColor).opacity(0.25)
    }
}

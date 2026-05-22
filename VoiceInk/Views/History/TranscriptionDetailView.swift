import SwiftUI

struct TranscriptionDetailView: View {
    let transcription: Transcription
    var onInfoTap: (() -> Void)?

    private var hasAudioFile: Bool {
        if let urlString = transcription.audioFileURL,
           let url = URL(string: urlString),
           FileManager.default.fileExists(atPath: url.path) {
            return true
        }
        return false
    }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(spacing: 16) {
                    MessageBubble(
                        label: "Original",
                        text: transcription.text,
                        isEnhanced: false
                    )

                    if let enhancedText = transcription.enhancedText {
                        MessageBubble(
                            label: "Enhanced",
                            text: enhancedText,
                            isEnhanced: true
                        )
                    }

                    if let log = APICallLog.decoded(from: transcription.troubleshootingLogJSON),
                       !log.steps.isEmpty {
                        TroubleshootingLogSection(log: log)
                    }
                }
                .padding(16)
            }

            if hasAudioFile, let urlString = transcription.audioFileURL,
               let url = URL(string: urlString) {
                VStack(spacing: 0) {
                    Divider()

                    AudioPlayerView(url: url, transcription: transcription, onInfoTap: onInfoTap)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

private struct MessageBubble: View {
    let label: String
    let text: String
    let isEnhanced: Bool

    var body: some View {
        HStack(alignment: .bottom) {
            if isEnhanced { Spacer(minLength: 60) }

            VStack(alignment: isEnhanced ? .leading : .trailing, spacing: 4) {
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 12)

                ScrollView {
                    Text(text)
                        .font(.system(size: 14, weight: .regular))
                        .lineSpacing(2)
                        .textSelection(.enabled)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .frame(maxHeight: 350)
                .background {
                    if isEnhanced {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color.accentColor.opacity(0.2))
                    } else {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.thinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                            )
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    CopyIconButton(textToCopy: text)
                        .padding(8)
                }
            }

            if !isEnhanced { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Troubleshooting log

private struct TroubleshootingLogSection: View {
    let log: APICallLog
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "ladybug.fill")
                        .foregroundColor(.secondary)
                    Text("Troubleshooting log")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("\(log.steps.count) call\(log.steps.count == 1 ? "" : "s")")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(log.steps) { step in
                        TroubleshootingStepCard(step: step)
                    }
                }
                .padding(.horizontal, 4)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 4)
    }
}

private struct TroubleshootingStepCard: View {
    let step: APICallLog.Step

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .foregroundColor(tint)
                    .font(.system(size: 11, weight: .semibold))
                Text(headerTitle)
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if let duration = step.durationMs {
                    Text("\(duration) ms")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }

            HStack(spacing: 6) {
                if let model = step.model {
                    Text(model)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(3)
                }
                if let lang = step.languageCode {
                    Text(lang)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(3)
                }
                if let host = step.endpointHost {
                    Text(host)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }

            if let request = step.requestSystemMessage, !request.isEmpty {
                logBlock(title: "System message", text: request)
            }
            if let userMsg = step.requestUserMessage, !userMsg.isEmpty {
                logBlock(title: "User message", text: userMsg)
            }
            if let summary = step.requestSummary, !summary.isEmpty,
               step.requestSystemMessage == nil, step.requestUserMessage == nil {
                logBlock(title: "Request", text: summary)
            }
            if let response = step.responseSummary, !response.isEmpty {
                logBlock(title: "Response", text: response)
            }
            if let error = step.errorMessage, !error.isEmpty {
                logBlock(title: "Error", text: error, tint: .red)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }

    private func logBlock(title: String, text: String, tint: Color = .secondary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(tint)
                Spacer()
                CopyIconButton(textToCopy: text)
            }
            ScrollView(.vertical, showsIndicators: true) {
                Text(text)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 180)
            .padding(8)
            .background(Color(NSColor.textBackgroundColor).opacity(0.6))
            .cornerRadius(6)
        }
    }

    private var headerTitle: String {
        let variant = step.providerVariant.map { " (\($0))" } ?? ""
        switch step.kind {
        case .stt: return "STT — \(step.provider)\(variant)"
        case .llm: return "LLM — \(step.provider)\(variant)"
        case .localCLI: return "Local CLI — \(step.provider)\(variant)"
        }
    }

    private var iconName: String {
        switch step.kind {
        case .stt: return "waveform"
        case .llm: return "bubble.left.and.bubble.right.fill"
        case .localCLI: return "terminal.fill"
        }
    }

    private var tint: Color {
        switch step.kind {
        case .stt: return .blue
        case .llm: return .purple
        case .localCLI: return .accentColor
        }
    }
}

import SwiftUI

/// Reusable component that displays transcription Details and AI Request sections.
/// Used in both the inline history sliding panel and the separate history window's metadata view.
struct TranscriptionInfoPanel: View {
    let transcription: Transcription

    var body: some View {
        Form {
            detailsSection
            troubleshootingLogSection
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Troubleshooting log

    @ViewBuilder
    private var troubleshootingLogSection: some View {
        if let log = APICallLog.decoded(from: transcription.troubleshootingLogJSON),
           !log.steps.isEmpty {
            Section {
                ForEach(log.steps) { step in
                    troubleshootingStepCard(step)
                }
                Text("Retention: 7 days. Tokens never stored — only assembled payloads and responses are captured.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } header: {
                HStack(spacing: 6) {
                    Image(systemName: "ladybug.fill")
                        .font(.system(size: 11))
                    Text("Troubleshooting Log")
                    Spacer()
                    Text("\(log.steps.count) call\(log.steps.count == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func troubleshootingStepCard(_ step: APICallLog.Step) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: stepIcon(step))
                    .foregroundColor(stepTint(step))
                    .font(.system(size: 11, weight: .semibold))
                Text(stepHeader(step))
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
                    pill(model)
                }
                if let lang = step.languageCode {
                    pill(lang)
                }
                if let host = step.endpointHost {
                    Text(host)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            if let req = step.requestSystemMessage, !req.isEmpty {
                logBlock(title: "System message", text: req)
            }
            if let user = step.requestUserMessage, !user.isEmpty {
                logBlock(title: "User message", text: user)
            }
            if let summary = step.requestSummary, !summary.isEmpty,
               step.requestSystemMessage == nil, step.requestUserMessage == nil {
                logBlock(title: "Request", text: summary)
            }
            if let response = step.responseSummary, !response.isEmpty {
                logBlock(title: "Response", text: response)
            }
            if let err = step.errorMessage, !err.isEmpty {
                logBlock(title: "Error", text: err, tint: .red)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }

    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(3)
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
            .frame(maxHeight: 160)
            .padding(8)
            .background(Color(NSColor.textBackgroundColor).opacity(0.6))
            .cornerRadius(6)
        }
    }

    private func stepHeader(_ step: APICallLog.Step) -> String {
        let variant = step.providerVariant.map { " (\($0))" } ?? ""
        switch step.kind {
        case .stt: return "STT — \(step.provider)\(variant)"
        case .llm: return "LLM — \(step.provider)\(variant)"
        case .localCLI: return "Local CLI — \(step.provider)\(variant)"
        }
    }

    private func stepIcon(_ step: APICallLog.Step) -> String {
        switch step.kind {
        case .stt: return "waveform"
        case .llm: return "bubble.left.and.bubble.right.fill"
        case .localCLI: return "terminal.fill"
        }
    }

    private func stepTint(_ step: APICallLog.Step) -> Color {
        switch step.kind {
        case .stt: return .blue
        case .llm: return .purple
        case .localCLI: return .accentColor
        }
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        Section {
            metadataRow(
                icon: "calendar",
                label: "Date",
                value: transcription.timestamp.formatted(date: .abbreviated, time: .shortened)
            )

            metadataRow(
                icon: "hourglass",
                label: "Duration",
                value: transcription.duration.formatTiming()
            )

            if let modelName = transcription.transcriptionModelName {
                metadataRow(
                    icon: "cpu.fill",
                    label: "Transcription Model",
                    value: modelName
                )

                if let duration = transcription.transcriptionDuration {
                    metadataRow(
                        icon: "clock.fill",
                        label: "Transcription Time",
                        value: duration.formatTiming()
                    )
                }
            }

            if let aiModel = transcription.aiEnhancementModelName {
                metadataRow(
                    icon: "sparkles",
                    label: "Enhancement Model",
                    value: aiModel
                )

                if let duration = transcription.enhancementDuration {
                    metadataRow(
                        icon: "clock.fill",
                        label: "Enhancement Time",
                        value: duration.formatTiming()
                    )
                }
            }

            if let promptName = transcription.promptName {
                metadataRow(
                    icon: "text.bubble.fill",
                    label: "Prompt",
                    value: promptName
                )
            }

            if let powerModeValue = powerModeDisplay(
                name: transcription.powerModeName,
                emoji: transcription.powerModeEmoji
            ) {
                metadataRow(
                    icon: "bolt.fill",
                    label: "Power Mode",
                    value: powerModeValue
                )
            }
        } header: {
            Text("Details")
        }
    }

    // MARK: - Helpers

    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }

    private func powerModeDisplay(name: String?, emoji: String?) -> String? {
        guard name != nil || emoji != nil else { return nil }

        switch (emoji?.trimmingCharacters(in: .whitespacesAndNewlines), name?.trimmingCharacters(in: .whitespacesAndNewlines)) {
        case let (.some(emojiValue), .some(nameValue)) where !emojiValue.isEmpty && !nameValue.isEmpty:
            return "\(emojiValue) \(nameValue)"
        case let (.some(emojiValue), _) where !emojiValue.isEmpty:
            return emojiValue
        case let (_, .some(nameValue)) where !nameValue.isEmpty:
            return nameValue
        default:
            return nil
        }
    }
}

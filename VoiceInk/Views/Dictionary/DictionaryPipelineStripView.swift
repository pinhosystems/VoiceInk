import SwiftUI

/// Visual provenance indicator shown above each Dictionary screen. Renders the
/// four pipeline stages an utterance goes through (audio → STT → LLM → paste)
/// with the active stage highlighted so the user can see at a glance WHERE
/// the data they are about to enter actually hits the system.
///
/// Vocabulary fires inside the STT stage (keyterm / Whisper prompt seed) and
/// also feeds into the LLM enhancement step as a vocabulary hint, so we
/// highlight both. Word Replacement fires after the LLM enhancement, right
/// before paste, so only the last stage is highlighted.
struct DictionaryPipelineStripView: View {
    enum Stage {
        /// Vocabulary: biases STT and feeds LLM context.
        case preTranscription
        /// Word Replacement: rewrites the final transcript before paste.
        case postPaste

        var label: String {
            switch self {
            case .preTranscription:
                return "Vocabulary fires here — before the transcript exists."
            case .postPaste:
                return "Word Replacement fires here — after the transcript is final."
            }
        }
    }

    let stage: Stage

    private struct PipelineStep: Identifiable {
        let id: Int
        let icon: String
        let title: String
    }

    private static let steps: [PipelineStep] = [
        PipelineStep(id: 0, icon: "mic.fill", title: "Audio"),
        PipelineStep(id: 1, icon: "waveform", title: "Transcription"),
        PipelineStep(id: 2, icon: "sparkles", title: "LLM enhancement"),
        PipelineStep(id: 3, icon: "doc.on.clipboard", title: "Paste")
    ]

    private func isActive(_ id: Int) -> Bool {
        switch stage {
        case .preTranscription:
            return id == 1 || id == 2
        case .postPaste:
            return id == 3
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(stage.label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.accentColor)

            HStack(spacing: 6) {
                ForEach(Array(Self.steps.enumerated()), id: \.element.id) { index, step in
                    stepView(step: step)

                    if index < Self.steps.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentColor.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.15), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func stepView(step: PipelineStep) -> some View {
        let active = isActive(step.id)
        HStack(spacing: 4) {
            Image(systemName: step.icon)
                .font(.system(size: 10, weight: active ? .semibold : .regular))
                .foregroundColor(active ? .accentColor : .secondary.opacity(0.7))
            Text(step.title)
                .font(.system(size: 11, weight: active ? .semibold : .regular))
                .foregroundColor(active ? .accentColor : .secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(active ? Color.accentColor.opacity(0.18) : Color.clear)
        )
    }
}

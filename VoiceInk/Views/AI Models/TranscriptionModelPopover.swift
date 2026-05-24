import SwiftUI

/// Compact popover that lets the user pick a transcription model on the
/// History row's audio player. Mirrors the dark-themed `PowerModePopover`
/// look so the three retry pickers (prompt / transcription model / Power
/// Mode) share a consistent visual treatment.
///
/// Selecting a row writes through `TranscriptionModelManager.setDefaultTranscriptionModel`,
/// which persists the choice via UserDefaults and makes it the model used
/// for the next Re-analyze or Retranscribe action triggered on the row.
struct TranscriptionModelPopover: View {
    @ObservedObject var transcriptionModelManager: TranscriptionModelManager
    @State private var selectedName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Transcription Model")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal)
                .padding(.top, 8)

            Divider()
                .background(Color.white.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if transcriptionModelManager.usableModels.isEmpty {
                        VStack(alignment: .center, spacing: 8) {
                            Image(systemName: "waveform")
                                .foregroundColor(.white.opacity(0.6))
                                .font(.system(size: 16))
                            Text("No transcription models available")
                                .foregroundColor(.white.opacity(0.8))
                                .font(.system(size: 13))
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    } else {
                        ForEach(transcriptionModelManager.usableModels, id: \.name) { model in
                            TranscriptionModelRow(
                                modelName: model.name,
                                displayName: model.displayName,
                                isSelected: selectedName == model.name,
                                action: {
                                    transcriptionModelManager.setDefaultTranscriptionModel(model)
                                    selectedName = model.name
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(width: 220)
        .frame(maxHeight: 340)
        .padding(.vertical, 8)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .onAppear {
            selectedName = transcriptionModelManager.currentTranscriptionModel?.name
        }
        .onChange(of: transcriptionModelManager.currentTranscriptionModel?.name) { _, newValue in
            selectedName = newValue
        }
    }
}

private struct TranscriptionModelRow: View {
    let modelName: String
    let displayName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "waveform")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.system(size: 12))

                Text(displayName)
                    .foregroundColor(.white.opacity(0.9))
                    .font(.system(size: 13))
                    .lineLimit(1)

                if isSelected {
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.white.opacity(0.10) : Color.clear)
        )
    }
}

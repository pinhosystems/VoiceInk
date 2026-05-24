import SwiftUI

/// Inline test sandbox embedded in the Enhancement screen. Lets the user paste
/// a transcript-style sentence and run it through the active prompt + provider
/// + model without having to record. Useful for tuning a prompt or sanity-
/// checking a freshly-added provider.
///
/// Calls `AIEnhancementService.enhance(_:)` directly so it sees the exact same
/// pipeline (system message, locale rules, context attachments) the recorder
/// uses. The only difference is that the input comes from the text area
/// instead of an STT output.
struct EnhancementTestSection: View {
    @EnvironmentObject private var enhancementService: AIEnhancementService

    @State private var isExpanded = false
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var errorMessage: String?
    @State private var isRunning = false
    @State private var lastDuration: TimeInterval?

    private static let defaultPlaceholder = "Paste or type a transcription here, then press Run to see the LLM rewrite it with the current prompt, provider, and model."

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 10) {
                    inputArea
                    runRow
                    if let errorMessage {
                        errorBanner(errorMessage)
                    }
                    if !outputText.isEmpty {
                        outputArea
                    }
                }
                .padding(.top, 6)
            } label: {
                HStack(spacing: 4) {
                    Text("Test enhancement")
                    InfoTip("Runs your input through the SAME pipeline VoiceInk would use after a recording — active prompt, provider, model, context attachments, and locale rules. The text never touches the STT engine.")
                }
            }
        } header: {
            Text("Sandbox")
        }
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Input")
                .font(.caption)
                .foregroundColor(.secondary)
            TextEditor(text: $inputText)
                .font(.system(size: 13))
                .frame(minHeight: 70, maxHeight: 140)
                .padding(6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
                )
                .overlay(alignment: .topLeading) {
                    if inputText.isEmpty {
                        Text(Self.defaultPlaceholder)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary.opacity(0.7))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var runRow: some View {
        HStack(spacing: 8) {
            Button {
                runTest()
            } label: {
                HStack(spacing: 6) {
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                    }
                    Text(isRunning ? "Running…" : "Run enhancement")
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .disabled(isRunning || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if !outputText.isEmpty || errorMessage != nil {
                Button("Clear") {
                    outputText = ""
                    errorMessage = nil
                    lastDuration = nil
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Spacer()

            if let duration = lastDuration {
                Text(String(format: "%.2fs", duration))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
            }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.caption)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private var outputArea: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Output")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(outputText, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Copy output to clipboard")
            }
            ScrollView {
                Text(outputText)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(minHeight: 70, maxHeight: 160)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
            )
        }
    }

    private func runTest() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        errorMessage = nil
        outputText = ""
        lastDuration = nil
        isRunning = true

        Task {
            do {
                let (result, duration, _) = try await enhancementService.enhance(trimmed)
                await MainActor.run {
                    outputText = result
                    lastDuration = duration
                    isRunning = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isRunning = false
                }
            }
        }
    }
}

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AppKit

struct InlineHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var expandedId: UUID?
    @State private var selectedTranscriptions: Set<Transcription> = []
    @State private var showDeleteConfirmation = false
    @State private var isPanelPresented = false
    @State private var panelMode: PanelMode = .info
    @State private var panelTranscriptionId: UUID?
    @State private var displayedTranscriptions: [Transcription] = []
    @State private var isLoading = false
    @State private var hasMoreContent = true
    @State private var lastTimestamp: Date?
    @State private var isViewCurrentlyVisible = false

    private let exportService = VoiceInkCSVExportService()
    private let pageSize = 20

    @Query(Self.createLatestTranscriptionIndicatorDescriptor()) private var latestTranscriptionIndicator: [Transcription]

    private static func createLatestTranscriptionIndicatorDescriptor() -> FetchDescriptor<Transcription> {
        var descriptor = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }

    private func cursorQueryDescriptor(after timestamp: Date? = nil) -> FetchDescriptor<Transcription> {
        var descriptor = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\Transcription.timestamp, order: .reverse)]
        )

        if let timestamp = timestamp {
            if !searchText.isEmpty {
                descriptor.predicate = #Predicate<Transcription> { transcription in
                    (transcription.text.localizedStandardContains(searchText) ||
                    (transcription.enhancedText?.localizedStandardContains(searchText) ?? false)) &&
                    transcription.timestamp < timestamp
                }
            } else {
                descriptor.predicate = #Predicate<Transcription> { transcription in
                    transcription.timestamp < timestamp
                }
            }
        } else if !searchText.isEmpty {
            descriptor.predicate = #Predicate<Transcription> { transcription in
                transcription.text.localizedStandardContains(searchText) ||
                (transcription.enhancedText?.localizedStandardContains(searchText) ?? false)
            }
        }

        descriptor.fetchLimit = pageSize
        return descriptor
    }

    private var allSelected: Bool {
        !displayedTranscriptions.isEmpty && displayedTranscriptions.allSatisfy { selectedTranscriptions.contains($0) }
    }

    private var panelTranscription: Transcription? {
        guard let id = panelTranscriptionId else { return nil }
        return displayedTranscriptions.first { $0.id == id }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()

            if displayedTranscriptions.isEmpty && !isLoading {
                emptyStateView
            } else {
                cardListView
            }

            if !selectedTranscriptions.isEmpty {
                Divider()
                selectionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedTranscriptions.isEmpty)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay {
            Color.black.opacity(isPanelPresented ? 0.1 : 0)
                .ignoresSafeArea()
                .allowsHitTesting(isPanelPresented)
                .onTapGesture {
                    withAnimation(.smooth(duration: 0.3)) {
                        isPanelPresented = false
                        panelMode = .info
                    }
                }
                .animation(.smooth(duration: 0.3), value: isPanelPresented)
        }
        .overlay(alignment: .trailing) {
            if isPanelPresented {
                panelContent
                    .frame(width: 400)
                    .frame(maxHeight: .infinity)
                    .background(Color(NSColor.windowBackgroundColor))
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(Color(NSColor.separatorColor))
                            .frame(width: 1)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 8, x: -2, y: 0)
                    .ignoresSafeArea()
                    .transition(.move(edge: .trailing))
            }
        }
        .animation(.smooth(duration: 0.3), value: isPanelPresented)
        .alert("Delete Selected Items?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelectedTranscriptions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. Are you sure you want to delete \(selectedTranscriptions.count) item\(selectedTranscriptions.count == 1 ? "" : "s")?")
        }
        .onAppear {
            isViewCurrentlyVisible = true
            Task { await loadInitialContent() }
        }
        .onDisappear {
            isViewCurrentlyVisible = false
        }
        .onChange(of: searchText) { _, _ in
            Task {
                await resetPagination()
                await loadInitialContent()
            }
        }
        .onChange(of: latestTranscriptionIndicator.first?.id) { oldId, newId in
            guard isViewCurrentlyVisible else { return }
            if newId != oldId {
                Task {
                    await resetPagination()
                    await loadInitialContent()
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Search transcriptions...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.08))
            )
            .frame(maxWidth: .infinity)

            Button(action: presentUploadPanel) {
                Label("Upload File", systemImage: "arrow.up.doc")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
            .softTooltip("Upload an audio or video file to transcribe")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    /// Opens an NSOpenPanel for audio/video files and, on confirmation,
    /// routes to the file-transcription view with the picked URL already
    /// enqueued. The two-step notification (route first, then file)
    /// mirrors the AppDelegate file-association flow so the receiving
    /// view is mounted before the file payload arrives.
    private func presentUploadPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .movie]
        guard panel.runModal() == .OK, let url = panel.url else { return }

        NotificationCenter.default.post(
            name: .navigateToDestination,
            object: nil,
            userInfo: ["destination": "File"]
        )
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .openFileForTranscription,
                object: nil,
                userInfo: ["url": url]
            )
        }
    }

    private var selectionBar: some View {
        HStack(spacing: 16) {
            Text("\(selectedTranscriptions.count) selected")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Spacer()

            Button(action: {
                panelMode = .analysis
                withAnimation(.smooth(duration: 0.3)) { isPanelPresented = true }
            }) {
                Label("Analyze", systemImage: "chart.bar.xaxis")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .softTooltip("Open performance analysis for the selected transcriptions")

            Button(action: {
                exportService.exportTranscriptionsToCSV(transcriptions: Array(selectedTranscriptions))
            }) {
                Label("Export", systemImage: "square.and.arrow.up")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .softTooltip("Export the selected transcriptions to CSV")

            // Manual Delete intentionally removed from the selection
            // bar — transcriptions and their audio are reaped by the
            // retention services (TranscriptionAutoCleanupService for
            // records + audio, TranscriptionLogRetentionService for
            // troubleshooting JSON). Surfacing a destructive button
            // alongside Analyze / Export invited fat-fingered losses.
            // Tweak retention windows in Settings → Cleanup if a faster
            // sweep is needed.

            Divider()
                .frame(height: 16)

            if allSelected {
                Button("Deselect All") {
                    selectedTranscriptions.removeAll()
                }
                .font(.system(size: 12, weight: .medium))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .softTooltip("Clear the current selection")
            } else {
                Button("Select All") {
                    Task { await selectAllTranscriptions() }
                }
                .font(.system(size: 12, weight: .medium))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .softTooltip("Select every transcription matching the current search")
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            Color(NSColor.windowBackgroundColor)
                .shadow(color: Color.black.opacity(0.1), radius: 3, y: -2)
        )
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "No transcriptions yet" : "No results found")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "Your transcription history will appear here" : "Try a different search term")
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.8))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Card List

    private var cardListView: some View {
        Form {
            ForEach(displayedTranscriptions) { transcription in
                Section {
                    HistoryCardRow(
                        transcription: transcription,
                        isExpanded: expandedId == transcription.id,
                        isChecked: selectedTranscriptions.contains(transcription),
                        onToggleExpand: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                expandedId = expandedId == transcription.id ? nil : transcription.id
                            }
                        },
                        onToggleCheck: { toggleSelection(transcription) },
                        onShowInfo: {
                            panelTranscriptionId = transcription.id
                            panelMode = .info
                            withAnimation(.smooth(duration: 0.3)) {
                                isPanelPresented = true
                            }
                        }
                    )
                }
            }

            if hasMoreContent {
                Section {
                    Button(action: {
                        Task { await loadMoreContent() }
                    }) {
                        HStack(spacing: 8) {
                            if isLoading {
                                ProgressView().controlSize(.small)
                            }
                            Text(isLoading ? "Loading..." : "Load More")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .disabled(isLoading)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Sliding Panel

    @ViewBuilder
    private var panelContent: some View {
        switch panelMode {
        case .info:
            infoPanelContent
        case .analysis:
            PerformanceAnalysisPanelView(
                transcriptions: Array(selectedTranscriptions),
                onClose: {
                    withAnimation(.smooth(duration: 0.3)) {
                        isPanelPresented = false
                        panelMode = .info
                    }
                }
            )
            .id(selectedTranscriptions.count)
        }
    }

    private var infoPanelContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("Info")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    withAnimation(.smooth(duration: 0.3)) {
                        isPanelPresented = false
                        panelMode = .info
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(Divider().opacity(0.5), alignment: .bottom)
            .zIndex(1)

            if let transcription = panelTranscription {
                TranscriptionInfoPanel(transcription: transcription)
                    .id(transcription.id)
            } else {
                Spacer()
            }
        }
    }

    // MARK: - Data Loading

    @MainActor
    private func loadInitialContent() async {
        isLoading = true
        defer { isLoading = false }

        do {
            lastTimestamp = nil
            let items = try modelContext.fetch(cursorQueryDescriptor())
            displayedTranscriptions = items
            lastTimestamp = items.last?.timestamp
            hasMoreContent = items.count == pageSize
        } catch {
            print("Error loading transcriptions: \(error)")
        }
    }

    @MainActor
    private func loadMoreContent() async {
        guard !isLoading, hasMoreContent, let lastTimestamp = lastTimestamp else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let newItems = try modelContext.fetch(cursorQueryDescriptor(after: lastTimestamp))
            displayedTranscriptions.append(contentsOf: newItems)
            self.lastTimestamp = newItems.last?.timestamp
            hasMoreContent = newItems.count == pageSize
        } catch {
            print("Error loading more transcriptions: \(error)")
        }
    }

    @MainActor
    private func resetPagination() {
        displayedTranscriptions = []
        lastTimestamp = nil
        hasMoreContent = true
        isLoading = false
    }

    // MARK: - Selection & Deletion

    private func toggleSelection(_ transcription: Transcription) {
        if selectedTranscriptions.contains(transcription) {
            selectedTranscriptions.remove(transcription)
        } else {
            selectedTranscriptions.insert(transcription)
        }
    }

    private func performDeletion(for transcription: Transcription) {
        if let urlString = transcription.audioFileURL,
           let url = URL(string: urlString),
           FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                print("Error deleting audio file: \(error.localizedDescription)")
            }
        }

        if expandedId == transcription.id {
            expandedId = nil
        }
        if panelTranscriptionId == transcription.id {
            panelTranscriptionId = nil
            isPanelPresented = false
        }

        selectedTranscriptions.remove(transcription)
        modelContext.delete(transcription)
    }

    private func deleteSelectedTranscriptions() {
        for transcription in selectedTranscriptions {
            performDeletion(for: transcription)
        }
        selectedTranscriptions.removeAll()

        Task {
            do {
                try modelContext.save()
                NotificationCenter.default.post(name: .transcriptionDeleted, object: nil)
                await loadInitialContent()
            } catch {
                print("Error saving deletion: \(error.localizedDescription)")
                await loadInitialContent()
            }
        }
    }

    private func selectAllTranscriptions() async {
        do {
            var allDescriptor = FetchDescriptor<Transcription>()

            if !searchText.isEmpty {
                allDescriptor.predicate = #Predicate<Transcription> { transcription in
                    transcription.text.localizedStandardContains(searchText) ||
                    (transcription.enhancedText?.localizedStandardContains(searchText) ?? false)
                }
            }

            allDescriptor.propertiesToFetch = [\.id]
            let allTranscriptions = try modelContext.fetch(allDescriptor)
            let visibleIds = Set(displayedTranscriptions.map { $0.id })

            await MainActor.run {
                selectedTranscriptions = Set(displayedTranscriptions)

                for transcription in allTranscriptions {
                    if !visibleIds.contains(transcription.id) {
                        selectedTranscriptions.insert(transcription)
                    }
                }
            }
        } catch {
            print("Error selecting all transcriptions: \(error)")
        }
    }
}

// MARK: - History Card Row

private struct HistoryCardRow: View {
    let transcription: Transcription
    let isExpanded: Bool
    let isChecked: Bool
    let onToggleExpand: () -> Void
    let onToggleCheck: () -> Void
    let onShowInfo: () -> Void

    @State private var selectedTab: TranscriptionTab = .original

    private var displayText: String {
        switch selectedTab {
        case .original:
            return transcription.text
        case .enhanced:
            return transcription.enhancedText ?? ""
        }
    }

    private var hasAudioFile: Bool {
        if let urlString = transcription.audioFileURL,
           let url = URL(string: urlString),
           FileManager.default.fileExists(atPath: url.path) {
            return true
        }
        return false
    }

    /// Trimmed power-mode label. Returns nil when the name is missing or
    /// blank so we don't render a hollow pill containing only the emoji.
    private var powerModeLabel: String? {
        guard let raw = transcription.powerModeName?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return raw
    }

    /// Short, humane timestamp: "Today at 10:35", "Yesterday at 14:20",
    /// "Mon at 09:15", or "May 22" for older records. The intent is to
    /// favor recognition over precision — the exact timestamp is one tap
    /// away in the info panel.
    private var humanTimestamp: String {
        let date = transcription.timestamp
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none
        let timeString = timeFormatter.string(from: date)

        if calendar.isDateInToday(date) {
            return "Today at \(timeString)"
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday at \(timeString)"
        }
        if let weekStart = calendar.date(byAdding: .day, value: -6, to: Date()),
           date > weekStart {
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEE"
            return "\(weekdayFormatter.string(from: date)) at \(timeString)"
        }
        let dateFormatter = DateFormatter()
        dateFormatter.setLocalizedDateFormatFromTemplate("MMMd")
        return dateFormatter.string(from: date)
    }

    /// Compact model label — the full name is preserved on hover via help,
    /// and the info panel always carries the unabbreviated value.
    private static func shortModelName(_ raw: String?, limit: Int = 18) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        if raw.count <= limit { return raw }
        return String(raw.prefix(limit - 1)) + "…"
    }

    @ViewBuilder
    private func metadataPill(icon: String?, emoji: String?, text: String, tint: Color, help: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let emoji, !emoji.isEmpty {
                Text(emoji)
                    .font(.system(size: 10))
            } else if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(tint)
            }
            Text(text)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(tint)
                .lineLimit(1)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(tint.opacity(0.12))
        )
        .softTooltip(help ?? text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                Toggle("", isOn: Binding(
                    get: { isChecked },
                    set: { _ in onToggleCheck() }
                ))
                .toggleStyle(CircularCheckboxStyle())
                .labelsHidden()
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(humanTimestamp)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("·")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.5))

                        Text(transcription.duration.formatTiming())
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    metadataRow

                    if !isExpanded {
                        Text(transcription.enhancedText ?? transcription.text)
                            .font(.system(size: 13))
                            .lineLimit(2)
                            .foregroundColor(.primary.opacity(0.85))
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    .padding(.top, 4)
            }
            .contentShape(Rectangle())
            .onTapGesture { onToggleExpand() }

            if isExpanded {
                expandedContent
                    .padding(.top, 10)
            }
        }
    }

    /// Pills row carrying — in priority order — the power mode, the prompt
    /// profile, the STT model, and the LLM model. Renders nothing when no
    /// metadata is present so legacy rows don't reserve dead space.
    @ViewBuilder
    private var metadataRow: some View {
        let powerMode = powerModeLabel
        let prompt = transcription.promptName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let sttFull = transcription.transcriptionModelName
        let llmFull = transcription.aiEnhancementModelName
        let sttShort = Self.shortModelName(sttFull)
        let llmShort = Self.shortModelName(llmFull)

        if powerMode != nil || (prompt?.isEmpty == false) || sttShort != nil || llmShort != nil {
            HStack(spacing: 5) {
                if let powerMode {
                    metadataPill(
                        icon: nil,
                        emoji: transcription.powerModeEmoji,
                        text: powerMode,
                        tint: .blue,
                        help: "Power Mode profile"
                    )
                }
                if let prompt, !prompt.isEmpty {
                    metadataPill(
                        icon: "sparkles",
                        emoji: nil,
                        text: prompt,
                        tint: .purple,
                        help: "Enhancement prompt"
                    )
                }
                if let sttShort {
                    metadataPill(
                        icon: "waveform",
                        emoji: nil,
                        text: sttShort,
                        tint: .teal,
                        help: "Transcription model: \(sttFull ?? sttShort)"
                    )
                }
                if let llmShort {
                    metadataPill(
                        icon: "cpu",
                        emoji: nil,
                        text: llmShort,
                        tint: .orange,
                        help: "Enhancement model: \(llmFull ?? llmShort)"
                    )
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tabs
            if transcription.enhancedText != nil {
                HStack(spacing: 4) {
                    ForEach(TranscriptionTab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedTab = tab
                            }
                        } label: {
                            Text(tab.rawValue)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(selectedTab == tab ? .primary : .secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(selectedTab == tab ? Color.secondary.opacity(0.15) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }

            ScrollView {
                Text(displayText)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 350)
            .overlay(alignment: .bottomTrailing) {
                CopyIconButton(textToCopy: displayText)
                    .padding(8)
            }

            if hasAudioFile, let urlString = transcription.audioFileURL,
               let url = URL(string: urlString) {
                Divider()
                AudioPlayerView(url: url, transcription: transcription, onInfoTap: onShowInfo)
                .padding(.vertical, 4)
            } else {
                HStack {
                    Spacer()
                    Button(action: onShowInfo) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .softTooltip("View details")
                }
            }
        }
    }

}


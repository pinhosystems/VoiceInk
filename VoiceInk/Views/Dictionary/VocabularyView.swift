import SwiftUI
import SwiftData

enum VocabularySortMode: String {
    case wordAsc = "wordAsc"
    case wordDesc = "wordDesc"
}

struct VocabularyView: View {
    @Query private var vocabularyWords: [VocabularyWord]
    @Environment(\.modelContext) private var modelContext
    @ObservedObject var whisperPrompt: WhisperPrompt
    @State private var newWord = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var sortMode: VocabularySortMode = .wordAsc
    @State private var showingBulkConfirmation = false
    @State private var showingTechnicalConfirmation = false
    @State private var showingClearConfirmation = false

    /// Resolves the active locale pack's curated vocabulary list. nil when no
    /// pack is active or when the pack's `vocabularyTerms` is empty — the
    /// bulk-add button is hidden in both cases to keep inert actions off the
    /// panel.
    private var activeVocabularyPack: LocalePack? {
        let lang = UserDefaults.standard.string(forKey: "SelectedLanguage")
        guard let pack = LocalePackRegistry.pack(for: lang),
              !pack.vocabularyTerms.isEmpty
        else { return nil }
        return pack
    }

    init(whisperPrompt: WhisperPrompt) {
        self.whisperPrompt = whisperPrompt

        if let savedSort = UserDefaults.standard.string(forKey: "vocabularySortMode"),
           let mode = VocabularySortMode(rawValue: savedSort) {
            _sortMode = State(initialValue: mode)
        }
    }

    private var sortedItems: [VocabularyWord] {
        switch sortMode {
        case .wordAsc:
            return vocabularyWords.sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedAscending }
        case .wordDesc:
            return vocabularyWords.sorted { $0.word.localizedCaseInsensitiveCompare($1.word) == .orderedDescending }
        }
    }

    private func toggleSort() {
        sortMode = (sortMode == .wordAsc) ? .wordDesc : .wordAsc
        UserDefaults.standard.set(sortMode.rawValue, forKey: "vocabularySortMode")
    }

    private var shouldShowAddButton: Bool {
        !newWord.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Label {
                        Text("Biases the speech recognizer toward these words. Cloud STT (Deepgram, Soniox, xAI, AssemblyAI, Speechmatics) consumes them as keyterm; local Whisper uses them as prompt seed. Works with or without AI enhancement.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                    }

                    Text("Use it for: proper nouns, product names, jargon, people's names — anything the engine mishears (e.g. \"voicing\" → VoiceInk, \"react query\" stays as one term).")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.leading, 22)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                TextField("Add word to vocabulary", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .onSubmit { addWords() }

                if shouldShowAddButton {
                    Button(action: addWords) {
                        Image(systemName: "plus.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.blue)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.borderless)
                    .disabled(newWord.isEmpty)
                    .help("Add word")
                }
            }
            .animation(.easeInOut(duration: 0.2), value: shouldShowAddButton)

            HStack(spacing: 8) {
                if let pack = activeVocabularyPack {
                    Button {
                        showingBulkConfirmation = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "wand.and.sparkles")
                            Text("Add \(pack.displayName) vocabulary")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .help("Inserts the curated \(pack.displayName) vocabulary list. Helps the LLM and cloud providers (Deepgram keyterm) get the spelling right.")
                    .confirmationDialog(
                        "Add \(pack.displayName) vocabulary?",
                        isPresented: $showingBulkConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Add \(pack.vocabularyTerms.count) terms") {
                            applyPackTemplate(pack: pack)
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Inserts the curated \(pack.displayName) vocabulary list. Entries already present are skipped.")
                    }
                }

                Button {
                    showingTechnicalConfirmation = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "curlybraces")
                        Text("Add technical vocabulary")
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.bordered)
                .help("Inserts canonical EN technical terms (React, TypeScript, useState, Docker, PostgreSQL, GitHub, ...). Pairs well with the Whisper Domain: Technical setting.")
                .confirmationDialog(
                    "Add technical vocabulary?",
                    isPresented: $showingTechnicalConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Add \(TechnicalVocabularyTemplate.count) terms") {
                        applyTechnicalTemplate()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Will insert technical terms like React, TypeScript, useState, Docker, Kubernetes, PostgreSQL, GitHub, npm, JWT, OAuth. Existing entries are skipped.")
                }

                Spacer()

                if !vocabularyWords.isEmpty {
                    Button(role: .destructive) {
                        showingClearConfirmation = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Clear all")
                        }
                        .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .help("Deletes every vocabulary word. This cannot be undone.")
                    .confirmationDialog(
                        "Clear all vocabulary?",
                        isPresented: $showingClearConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button("Delete \(vocabularyWords.count) words", role: .destructive) {
                            clearAll()
                        }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Removes every vocabulary word. This cannot be undone.")
                    }
                }
            }

            if !vocabularyWords.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Button(action: toggleSort) {
                        HStack(spacing: 4) {
                            Text("Vocabulary Words (\(vocabularyWords.count))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)

                            Image(systemName: sortMode == .wordAsc ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                    .buttonStyle(.plain)
                    .help("Sort alphabetically")

                    ScrollView {
                        FlowLayout(spacing: 8) {
                            ForEach(sortedItems) { item in
                                VocabularyWordView(item: item) {
                                    removeWord(item)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .frame(maxHeight: 200)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .alert("Vocabulary", isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func addWords() {
        let input = newWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        if let error = DictionaryService.addVocabularyWords(input, existing: Array(vocabularyWords), context: modelContext) {
            alertMessage = error
            showAlert = true
            return
        }
        newWord = ""
    }

    private func removeWord(_ word: VocabularyWord) {
        modelContext.delete(word)

        do {
            try modelContext.save()
        } catch {
            // Rollback the delete to restore UI consistency
            modelContext.rollback()
            alertMessage = "Failed to remove word: \(error.localizedDescription)"
            showAlert = true
        }
    }

    private func applyPackTemplate(pack: LocalePack) {
        let result = DictionaryService.addPackVocabulary(
            pack: pack,
            existing: Array(vocabularyWords),
            context: modelContext
        )
        presentBulkResult(result)
    }

    private func applyTechnicalTemplate() {
        let result = DictionaryService.addTechnicalVocabulary(
            existing: Array(vocabularyWords),
            context: modelContext
        )
        presentBulkResult(result)
    }

    private func clearAll() {
        if let deleted = DictionaryService.clearAllVocabulary(context: modelContext) {
            alertMessage = "Deleted \(deleted) words."
        } else {
            alertMessage = "Failed to clear vocabulary."
        }
        showAlert = true
    }

    private func presentBulkResult(_ result: DictionaryService.BulkInsertResult) {
        if !result.errors.isEmpty {
            alertMessage = "Added: \(result.added). Skipped: \(result.skipped). Errors: \(result.errors.joined(separator: "; "))"
        } else {
            alertMessage = "Added: \(result.added). Skipped (already exist): \(result.skipped)."
        }
        showAlert = true
    }
}

struct VocabularyWordView: View {
    let item: VocabularyWord
    let onDelete: () -> Void
    @State private var isDeleteHovered = false

    var body: some View {
        HStack(spacing: 6) {
            Text(item.word)
                .font(.system(size: 13))
                .lineLimit(1)
                .foregroundColor(.primary)

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isDeleteHovered ? .red : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.borderless)
            .help("Remove word")
            .onHover { hover in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isDeleteHovered = hover
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.windowBackgroundColor).opacity(0.4))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.05), radius: 2, y: 1)
    }
} 

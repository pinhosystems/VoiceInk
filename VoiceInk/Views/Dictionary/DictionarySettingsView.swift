import SwiftUI
import SwiftData
import KeyboardShortcuts

struct DictionarySettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedSection: DictionarySection = .replacements
    let whisperPrompt: WhisperPrompt

    enum DictionarySection: String, CaseIterable, Identifiable {
        case replacements = "Word Replacements"
        case spellings = "Vocabulary"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .spellings:
                return "character.book.closed.fill"
            case .replacements:
                return "arrow.2.squarepath"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                mainContent
            }
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var heroSection: some View {
        CompactHeroSection(
            icon: "brain.filled.head.profile",
            title: "Dictionary",
            description: "Teach VoiceInk new words so the engine recognizes them, and rewrite text after it's transcribed.",
            maxDescriptionWidth: 520
        )
    }

    private var mainContent: some View {
        VStack(spacing: 24) {
            sectionSelector
            quickAddTip
            selectedSectionContent
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 32)
    }

    private var sectionSelector: some View {
        Picker("", selection: $selectedSection) {
            ForEach(DictionarySection.allCases) { section in
                Label(section.rawValue, systemImage: section.icon)
                    .tag(section)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 420)
    }

    private var quickAddTip: some View {
        let shortcut = KeyboardShortcuts.getShortcut(for: .quickAddToDictionary)
        return HStack(spacing: 6) {
            Image(systemName: "command")
                .font(.system(size: 11))
            if let shortcut {
                Text("Quick Add anywhere: ")
                + Text(shortcut.description).bold()
            } else {
                Text("Set a Quick Add shortcut in Settings → Additional Shortcuts to add words without leaving the current app.")
            }
        }
        .font(.system(size: 11))
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var selectedSectionContent: some View {
        switch selectedSection {
        case .spellings:
            VocabularyView(whisperPrompt: whisperPrompt)
                .background(CardBackground(isSelected: false))
        case .replacements:
            WordReplacementView()
                .background(CardBackground(isSelected: false))
        }
    }
}

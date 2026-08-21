import SwiftUI
import Cocoa
import KeyboardShortcuts
import LaunchAtLogin
import AVFoundation

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var updaterViewModel: UpdaterViewModel
    @EnvironmentObject private var menuBarManager: MenuBarManager
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @EnvironmentObject private var recorderUIManager: RecorderUIManager
    @EnvironmentObject private var transcriptionModelManager: TranscriptionModelManager
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @StateObject private var deviceManager = AudioDeviceManager.shared
    @ObservedObject private var soundManager = SoundManager.shared
    @ObservedObject private var mediaController = MediaController.shared
    @ObservedObject private var playbackController = PlaybackController.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = true
    // `autoUpdateCheck` no longer surfaced in the UI — see UpdaterViewModel
    // in VoiceInk.swift. The default is registered in AppDefaults so any code
    // reading the key still gets a stable value.
    @AppStorage("enableAnnouncements") private var enableAnnouncements = true
    @AppStorage("restoreClipboardAfterPaste") private var restoreClipboardAfterPaste = true
    @AppStorage("clipboardRestoreDelay") private var clipboardRestoreDelay = 2.0
    @AppStorage("useAppleScriptPaste") private var useAppleScriptPaste = false
    @State private var showResetOnboardingAlert = false
    @State private var currentShortcut = KeyboardShortcuts.getShortcut(for: .toggleMiniRecorder)
    @State private var isCustomCancelEnabled = KeyboardShortcuts.getShortcut(for: .cancelRecorder) != nil
    // Dictionary is reached from Advanced → "Open Dictionary…" as a modal
    // sheet rather than a sidebar destination. We deliberately do NOT route
    // through the global `.navigateToDestination` notification + ContentView
    // selectedView swap: `List(selection:)` in the NavigationSplitView only
    // accepts values that exist as a sidebar row, and Dictionary is hidden
    // from the sidebar by design. The notification path was a no-op because
    // of that clamping. A self-contained sheet on SettingsView is the right
    // affordance here — the workflow is "open, edit, close".
    @State private var isShowingDictionarySheet = false
    @State private var isShowingAudioInputSheet = false

    // Expansion states - all collapsed by default
    @State private var isCustomCancelExpanded = false
    @State private var isMiddleClickExpanded = false
    @State private var isSoundFeedbackExpanded = false
    @State private var isMuteSystemExpanded = false
    @State private var isPauseMediaExpanded = false
    @State private var isRestoreClipboardExpanded = false

    @AppStorage("DefaultAppLanguage") private var defaultAppLanguage: String = "en"
    @AppStorage("SelectedLanguage") private var selectedLanguage: String = "en"
    @AppStorage(LocalePackRegistry.outputLanguageKey)
    private var llmOutputLanguage: String = LocalePackRegistry.outputLanguageMatchSentinel

    /// Curated list of language profiles the user can pick as their default.
    /// Variants are explicitly listed so the picker can preserve "Brazilian
    /// Portuguese" vs. "Portuguese" rather than collapsing them at the source.
    /// Per-context pickers (STT model language, LLM output language, etc.) use
    /// `LanguageFallbackResolver.resolve` to map this choice against the
    /// codes they actually support, falling back to the generic primary
    /// subtag when the regional variant is missing.
    private static let defaultLanguageOptions: [(code: String, label: String)] = [
        ("auto", "Auto-detect (per provider)"),
        ("en", "English"),
        ("en-US", "English (United States)"),
        ("en-GB", "English (United Kingdom)"),
        ("en-AU", "English (Australia)"),
        ("pt", "Portuguese"),
        ("pt-BR", "Portuguese (Brazil)"),
        ("pt-PT", "Portuguese (Portugal)"),
        ("es", "Spanish"),
        ("es-ES", "Spanish (Spain)"),
        ("es-MX", "Spanish (Mexico)"),
        ("fr", "French"),
        ("fr-FR", "French (France)"),
        ("fr-CA", "French (Canada)"),
        ("de", "German"),
        ("de-DE", "German (Germany)"),
        ("de-AT", "German (Austria)"),
        ("de-CH", "German (Switzerland)"),
        ("it", "Italian"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("zh", "Chinese (Simplified)"),
        ("zh-TW", "Chinese (Traditional)")
    ]

    /// Mirrors EnhancementLocaleSection.outputLanguageOptions; used to resolve
    /// the picker selection against the LLM output-language picker's hard-
    /// coded list when the default app language propagates.
    private static let llmOutputLanguageCodes: [String] = [
        "en", "pt-BR", "pt-PT", "es", "fr", "de", "it", "ja", "ko", "zh"
    ]

    private enum SettingsTab: String, CaseIterable, Identifiable {
        case general, shortcuts, recording, data, advanced

        var id: String { rawValue }

        var label: String {
            switch self {
            case .general: return "General"
            case .shortcuts: return "Shortcuts"
            case .recording: return "Recording"
            case .data: return "Data"
            case .advanced: return "Advanced"
            }
        }

        var icon: String {
            switch self {
            case .general: return "gear"
            case .shortcuts: return "keyboard"
            case .recording: return "mic.fill"
            case .data: return "folder.fill"
            case .advanced: return "wrench.and.screwdriver.fill"
            }
        }
    }

    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // Top breathing room — the TabView tab strip sits glued to the
            // window chrome otherwise, which reads as cramped on macOS.
            Spacer()
                .frame(height: 16)

            TabView(selection: $selectedTab) {
                generalTab
                    .tabItem { Label(SettingsTab.general.label, systemImage: SettingsTab.general.icon) }
                    .tag(SettingsTab.general)

                shortcutsTab
                    .tabItem { Label(SettingsTab.shortcuts.label, systemImage: SettingsTab.shortcuts.icon) }
                    .tag(SettingsTab.shortcuts)

                recordingTab
                    .tabItem { Label(SettingsTab.recording.label, systemImage: SettingsTab.recording.icon) }
                    .tag(SettingsTab.recording)

                dataTab
                    .tabItem { Label(SettingsTab.data.label, systemImage: SettingsTab.data.icon) }
                    .tag(SettingsTab.data)

                advancedTab
                    .tabItem { Label(SettingsTab.advanced.label, systemImage: SettingsTab.advanced.icon) }
                    .tag(SettingsTab.advanced)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .alert("Reset Onboarding", isPresented: $showResetOnboardingAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                DispatchQueue.main.async {
                    hasCompletedOnboarding = false
                }
            }
        } message: {
            Text("You'll see the introduction screens again the next time you launch the app.")
        }
    }

    // MARK: - General tab — Language + general app preferences

    private var generalTab: some View {
        Form {
            // MARK: - Language (mandatory)
            Section {
                Picker(selection: $defaultAppLanguage) {
                    ForEach(Self.defaultLanguageOptions, id: \.code) { option in
                        Text(option.label).tag(option.code)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Default language")
                        InfoTip("Your primary language. Resolves live at every runtime read for surfaces that left the inherit option selected (AI Models on \"Default\", Enhancement on \"Match transcription language\", Power Mode on \"Inherit from Settings\"). Explicit overrides in any of those screens are preserved and untouched by changes here. Regional variants resolve to their generic primary subtag when a downstream context does not expose the exact code (en-US → en, pt-BR → pt, etc.).")
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: defaultAppLanguage) { _, newValue in
                    propagateDefaultLanguage(newValue)
                }

                Text("Updates every per-context picker still set to inherit from Settings. Explicit overrides you set elsewhere are preserved.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Language")
            }

            Section("General") {
                Toggle("Hide Dock Icon", isOn: $menuBarManager.isMenuBarOnly)

                LaunchAtLogin.Toggle("Launch at Login")

                Toggle("Show Announcements", isOn: $enableAnnouncements)
                    .onChange(of: enableAnnouncements) { _, newValue in
                        if newValue {
                            AnnouncementsService.shared.start()
                        } else {
                            AnnouncementsService.shared.stop()
                        }
                    }

                HStack {
                    Button("Reset Onboarding") {
                        showResetOnboardingAlert = true
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(NSColor.controlBackgroundColor))
        .padding(.top, 12)
    }

    // MARK: - Shortcuts tab

    private var shortcutsTab: some View {
        Form {
            // MARK: - Shortcuts
            Section {
                LabeledContent("Shortcut 1") {
                    HStack(spacing: 8) {
                        Spacer()
                        if hotkeyManager.selectedHotkey1 != .none {
                            hotkeyModePicker(binding: $hotkeyManager.hotkeyMode1)
                        }
                        hotkeyPicker(binding: $hotkeyManager.selectedHotkey1)
                        if hotkeyManager.selectedHotkey1 == .custom {
                            KeyboardShortcuts.Recorder(for: .toggleMiniRecorder)
                                .controlSize(.small)
                        }
                    }
                }

                if hotkeyManager.selectedHotkey2 != .none {
                    LabeledContent("Shortcut 2") {
                        HStack(spacing: 8) {
                            Spacer()
                            hotkeyModePicker(binding: $hotkeyManager.hotkeyMode2)
                            hotkeyPicker(binding: $hotkeyManager.selectedHotkey2)
                            if hotkeyManager.selectedHotkey2 == .custom {
                                KeyboardShortcuts.Recorder(for: .toggleMiniRecorder2)
                                    .controlSize(.small)
                            }
                            Button {
                                withAnimation { hotkeyManager.selectedHotkey2 = .none }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if hotkeyManager.selectedHotkey1 != .none && hotkeyManager.selectedHotkey2 == .none {
                    Button("Add Second Shortcut") {
                        withAnimation { hotkeyManager.selectedHotkey2 = .rightOption }
                    }
                }
            } header: {
                Text("Shortcuts")
            }

            // MARK: - Additional Shortcuts
            Section("Additional Shortcuts") {
                LabeledContent("Paste Last Transcription (Original)") {
                    KeyboardShortcuts.Recorder(for: .pasteLastTranscription)
                        .controlSize(.small)
                }

                LabeledContent("Paste Last Transcription (Enhanced)") {
                    KeyboardShortcuts.Recorder(for: .pasteLastEnhancement)
                        .controlSize(.small)
                }

                LabeledContent("Retry Last Transcription") {
                    KeyboardShortcuts.Recorder(for: .retryLastTranscription)
                        .controlSize(.small)
                }

                LabeledContent("Quick Add to Dictionary") {
                    KeyboardShortcuts.Recorder(for: .quickAddToDictionary)
                        .controlSize(.small)
                }

                // Custom Cancel - hierarchical
                ExpandableSettingsRow(
                    isExpanded: $isCustomCancelExpanded,
                    isEnabled: $isCustomCancelEnabled,
                    label: "Custom Cancel Shortcut"
                ) {
                    LabeledContent("Shortcut") {
                        KeyboardShortcuts.Recorder(for: .cancelRecorder)
                            .controlSize(.small)
                    }
                }
                .onChange(of: isCustomCancelEnabled) { _, newValue in
                    if !newValue {
                        KeyboardShortcuts.setShortcut(nil, for: .cancelRecorder)
                        isCustomCancelExpanded = false
                    }
                }

                // Middle-Click
                ExpandableSettingsRow(
                    isExpanded: $isMiddleClickExpanded,
                    isEnabled: $hotkeyManager.isMiddleClickToggleEnabled,
                    label: "Middle-Click Recording"
                ) {
                    LabeledContent("Activation Delay") {
                        HStack {
                            TextField("", value: $hotkeyManager.middleClickActivationDelay, formatter: {
                                let formatter = NumberFormatter()
                                formatter.minimum = 0
                                return formatter
                            }())
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 60)
                            Text("ms")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(NSColor.controlBackgroundColor))
        .padding(.top, 12)
    }

    // MARK: - Recording tab — feedback + interface

    private var recordingTab: some View {
        Form {
            // MARK: - Input Device (rarely-changed; deep screen behind a button)
            Section {
                LabeledContent("Microphone & Input Mode") {
                    Button("Open Audio Input…") {
                        isShowingAudioInputSheet = true
                    }
                }
            } header: {
                Text("Input Device")
            } footer: {
                Text("Choose between the system default, a specific microphone, or a prioritized fallback list. Most users set this once and never revisit it.")
            }

            // MARK: - Recording Feedback
            Section("Recording Feedback") {
                // Sound Feedback
                ExpandableSettingsRow(
                    isExpanded: $isSoundFeedbackExpanded,
                    isEnabled: $soundManager.isEnabled,
                    label: "Sound Feedback"
                ) {
                    CustomSoundSettingsView()
                }

                // Mute System Audio
                ExpandableSettingsRow(
                    isExpanded: $isMuteSystemExpanded,
                    isEnabled: $mediaController.isSystemMuteEnabled,
                    label: "Mute Audio While Recording"
                ) {
                    Picker("Resume Delay", selection: $mediaController.audioResumptionDelay) {
                        Text("0s").tag(0.0)
                        Text("1s").tag(1.0)
                        Text("2s").tag(2.0)
                        Text("3s").tag(3.0)
                        Text("4s").tag(4.0)
                        Text("5s").tag(5.0)
                    }
                }

                // Pause Media
                ExpandableSettingsRow(
                    isExpanded: $isPauseMediaExpanded,
                    isEnabled: $playbackController.isPauseMediaEnabled,
                    label: "Pause Media While Recording",
                    infoMessage: "Pauses playing media when recording starts and resumes when done."
                ) {
                    Picker("Resume Delay", selection: $mediaController.audioResumptionDelay) {
                        Text("0s").tag(0.0)
                        Text("1s").tag(1.0)
                        Text("2s").tag(2.0)
                        Text("3s").tag(3.0)
                        Text("4s").tag(4.0)
                        Text("5s").tag(5.0)
                    }
                }

                // Restore Clipboard
                ExpandableSettingsRow(
                    isExpanded: $isRestoreClipboardExpanded,
                    isEnabled: $restoreClipboardAfterPaste,
                    label: "Restore Clipboard After Paste"
                ) {
                    Picker("Restore Delay", selection: $clipboardRestoreDelay) {
                        Text("250ms").tag(0.25)
                        Text("500ms").tag(0.5)
                        Text("1s").tag(1.0)
                        Text("2s").tag(2.0)
                        Text("3s").tag(3.0)
                        Text("4s").tag(4.0)
                        Text("5s").tag(5.0)
                    }
                }

                // AppleScript Paste
                Toggle(isOn: $useAppleScriptPaste) {
                    HStack(spacing: 4) {
                        Text("Use AppleScript Paste")
                        InfoTip("Enable this if pasting doesn't work with your keyboard layout (e.g. Neo2). Uses AppleScript instead of simulated key events.")
                    }
                }

            }

            // MARK: - Interface
            Section("Interface") {
                Picker("Recorder Style", selection: $recorderUIManager.recorderType) {
                    Text("Notch").tag("notch")
                    Text("Mini").tag("mini")
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(NSColor.controlBackgroundColor))
        .padding(.top, 12)
        .sheet(isPresented: $isShowingAudioInputSheet) {
            // Same modal pattern as Dictionary: AudioInputSettingsView ships
            // no close affordance of its own, so wrap it in a NavigationStack
            // and add a Done button at the wrapper level to dismiss the sheet.
            NavigationStack {
                AudioInputSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                isShowingAudioInputSheet = false
                            }
                        }
                    }
            }
            .frame(minWidth: 720, minHeight: 560)
        }
    }

    // MARK: - Data tab — Privacy + Backup

    private var dataTab: some View {
        Form {
            // MARK: - Privacy
            Section {
                AudioCleanupSettingsView()
            } header: {
                Text("Privacy")
            } footer: {
                Text("Control how VoiceInk handles your transcription data and audio recordings.")
            }

            // MARK: - Backup
            Section {
                LabeledContent("Export Settings") {
                    Button("Export") {
                        ImportExportService.shared.exportSettings(
                            enhancementService: enhancementService,
                            whisperPrompt: WhisperPrompt(),
                            hotkeyManager: hotkeyManager,
                            menuBarManager: menuBarManager,
                            mediaController: mediaController,
                            playbackController: playbackController,
                            soundManager: soundManager,
                            recorderUIManager: recorderUIManager,
                            modelContext: modelContext
                        )
                    }
                }

                LabeledContent("Import Settings") {
                    Button("Import") {
                        ImportExportService.shared.importSettings(
                            enhancementService: enhancementService,
                            whisperPrompt: WhisperPrompt(),
                            hotkeyManager: hotkeyManager,
                            menuBarManager: menuBarManager,
                            mediaController: mediaController,
                            playbackController: playbackController,
                            soundManager: soundManager,
                            recorderUIManager: recorderUIManager,
                            modelContext: modelContext,
                            transcriptionModelManager: transcriptionModelManager
                        )
                    }
                }
            } header: {
                Text("Backup")
            } footer: {
                Text("Export all settings, or choose specific categories when importing a backup.")
            }

        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(NSColor.controlBackgroundColor))
        .padding(.top, 12)
    }

    // MARK: - Advanced tab — Dictionary + Diagnostics

    private var advancedTab: some View {
        Form {
            // MARK: - Dictionary (secondary)
            Section {
                LabeledContent("Vocabulary & Word Replacements") {
                    Button("Open Dictionary…") {
                        isShowingDictionarySheet = true
                    }
                }
            } header: {
                HStack(spacing: 4) {
                    Text("Dictionary")
                    InfoTip("Two-tab editor: Vocabulary biases the STT engine toward proper nouns and jargon; Word Replacements rewrites the final transcript. Most users never touch this — leave it alone unless the engine consistently mishears a specific term.")
                }
            }

            // MARK: - Diagnostics
            Section("Diagnostics") {
                DiagnosticsSettingsView()
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .background(Color(NSColor.controlBackgroundColor))
        .padding(.top, 12)
        .sheet(isPresented: $isShowingDictionarySheet) {
            // Wrap DictionarySettingsView in a fixed-size NavigationStack so
            // it gets a title bar with a Done button to dismiss the sheet.
            // The inner view doesn't ship its own close affordance because
            // when it lived in the sidebar the navigation chrome did that
            // job; here in a modal sheet we add it back at the wrapper level.
            NavigationStack {
                DictionarySettingsView(whisperPrompt: WhisperPrompt())
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                isShowingDictionarySheet = false
                            }
                        }
                    }
            }
            .frame(minWidth: 720, minHeight: 560)
        }
    }

    @ViewBuilder
    private func hotkeyPicker(binding: Binding<HotkeyManager.HotkeyOption>) -> some View {
        Picker("", selection: binding) {
            ForEach(HotkeyManager.HotkeyOption.allCases, id: \.self) { option in
                Text(option.displayName).tag(option)
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    @ViewBuilder
    private func hotkeyModePicker(binding: Binding<HotkeyManager.HotkeyMode>) -> some View {
        Picker("", selection: binding) {
            ForEach(HotkeyManager.HotkeyMode.allCases, id: \.self) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        .labelsHidden()
        .fixedSize()
    }

    /// Fires after the user picks a new `DefaultAppLanguage`.
    ///
    /// The downstream pickers (AI Models STT, Enhancement LLM, Power Mode
    /// profile language) are sentinel-based: surfaces left on
    /// `LanguageResolver.defaultSentinel` ("default") for STT, `"match"`
    /// for LLM, or `nil` for Power Mode resolve through Settings at every
    /// runtime read via `LanguageResolver.effectiveSTTCode(...)` and
    /// `LocalePackRegistry.outputLanguageCode(sttCode:)`. So this callback
    /// no longer writes anything — explicit customizations the user made
    /// in the downstream pickers are preserved. The notification fired by
    /// `LanguageDefaultPropagator.apply` re-renders any open view that
    /// displays a resolved label.
    private func propagateDefaultLanguage(_ newDefault: String) {
        LanguageDefaultPropagator.apply(newDefault)
    }
}

// MARK: - Expandable Settings Row (entire row clickable)

struct ExpandableSettingsRow<Content: View>: View {
    @Binding var isExpanded: Bool
    @Binding var isEnabled: Bool
    let label: String
    var infoMessage: String? = nil
    var infoURL: String? = nil
    @ViewBuilder let content: () -> Content

    @State private var isHandlingToggleChange = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row - entire area is tappable
            HStack {
                Toggle(isOn: $isEnabled) {
                    HStack(spacing: 4) {
                        Text(label)
                        if let message = infoMessage {
                            if let url = infoURL {
                                InfoTip(message, learnMoreURL: url)
                            } else {
                                InfoTip(message)
                            }
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .rotationEffect(.degrees(isEnabled && isExpanded ? 90 : 0))
                    .opacity(isEnabled ? 1 : 0.4)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isHandlingToggleChange else { return }
                if isEnabled {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                }
            }

            // Expanded content with proper spacing
            if isEnabled && isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    content()
                }
                .padding(.top, 12)
                .padding(.leading, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
        .onChange(of: isEnabled) { _, newValue in
            isHandlingToggleChange = true
            if newValue {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded = true
                }
            } else {
                isExpanded = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isHandlingToggleChange = false
            }
        }
    }
}

// MARK: - Text Extension

extension Text {
    func settingsDescription() -> some View {
        self
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

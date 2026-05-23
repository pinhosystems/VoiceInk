import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

enum ModelFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case local = "Local"
    case cloud = "Cloud"
    case custom = "Custom"
    var id: String { self.rawValue }
}

struct ModelManagementView: View {
    @EnvironmentObject private var whisperModelManager: WhisperModelManager
    @EnvironmentObject private var fluidAudioModelManager: FluidAudioModelManager
    @EnvironmentObject private var transcriptionModelManager: TranscriptionModelManager
    @EnvironmentObject private var enhancementService: AIEnhancementService
    @Environment(\.modelContext) private var modelContext
    @StateObject private var whisperPrompt = WhisperPrompt()
    @ObservedObject private var warmupCoordinator = WhisperModelWarmupCoordinator.shared

    @State private var selectedFilter: ModelFilter = .all
    @State private var isShowingSettings = false

    private let settingsPanelWidth: CGFloat = 400

    // State for the unified alert
    @State private var isShowingDeleteAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var deleteActionClosure: () -> Void = {}

    private func closeSettings() {
        withAnimation(.smooth(duration: 0.3)) {
            isShowingSettings = false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if SystemArchitecture.isIntelMac {
                    intelMacWarningBanner
                }

                defaultModelSection
                languageSelectionSection
                availableModelsSection
            }
            .padding(40)
        }
        .frame(minWidth: 600, minHeight: 500)
        .background(Color(NSColor.controlBackgroundColor))
        .slidingPanel(isPresented: $isShowingSettings, width: settingsPanelWidth) {
            settingsPanelContent
        }
        .alert(isPresented: $isShowingDeleteAlert) {
            Alert(
                title: Text(alertTitle),
                message: Text(alertMessage),
                primaryButton: .destructive(Text("Delete"), action: deleteActionClosure),
                secondaryButton: .cancel()
            )
        }
    }

    private var settingsPanelContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Text("Model Settings")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                Button(action: { closeSettings() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color.secondary.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.windowBackgroundColor))
            .overlay(
                Divider().opacity(0.5), alignment: .bottom
            )

            // Content
            ModelSettingsView(whisperPrompt: whisperPrompt)
        }
    }
    
    private var defaultModelSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Default Model")
                .font(.headline)
                .foregroundColor(.secondary)
            Text(transcriptionModelManager.currentTranscriptionModel?.displayName ?? "No model selected")
                .font(.title2)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground(isSelected: false))
        .cornerRadius(10)
    }

    private var languageSelectionSection: some View {
        LanguageSelectionView(transcriptionModelManager: transcriptionModelManager, displayMode: .full, whisperPrompt: whisperPrompt)
    }

    private var availableModelsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 12) {
                    ForEach(ModelFilter.allCases, id: \.self) { filter in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedFilter = filter
                                isShowingSettings = false
                            }
                        }) {
                            Text(filter.rawValue)
                                .font(.system(size: 14, weight: selectedFilter == filter ? .semibold : .medium))
                                .foregroundColor(selectedFilter == filter ? .primary : .primary.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    CardBackground(isSelected: selectedFilter == filter, cornerRadius: 22)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }

                Spacer()

                Button(action: {
                    withAnimation(.smooth(duration: 0.3)) {
                        isShowingSettings.toggle()
                    }
                }) {
                    Image(systemName: "gear")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isShowingSettings ? .accentColor : .primary.opacity(0.7))
                        .padding(12)
                        .background(
                            CardBackground(isSelected: isShowingSettings, cornerRadius: 22)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.bottom, 12)

            if filteredModels.isEmpty {
                emptyModelsState
            } else {
                VStack(spacing: 12) {
                    ForEach(filteredModels, id: \.id) { model in
                        let isWarming = (model as? WhisperModel).map { whisperModel in
                            warmupCoordinator.isWarming(modelNamed: whisperModel.name)
                        } ?? false

                        ModelCardView(
                            model: model,
                            fluidAudioModelManager: fluidAudioModelManager,
                            transcriptionModelManager: transcriptionModelManager,
                            isDownloaded: whisperModelManager.availableModels.contains { $0.name == model.name },
                            isCurrent: transcriptionModelManager.currentTranscriptionModel?.name == model.name,
                            downloadProgress: whisperModelManager.downloadProgress,
                            modelURL: whisperModelManager.availableModels.first { $0.name == model.name }?.url,
                            isWarming: isWarming,
                            deleteAction: { presentDeleteAlert(for: model) },
                            setDefaultAction: {
                                Task { transcriptionModelManager.setDefaultTranscriptionModel(model) }
                            },
                            downloadAction: {
                                if let whisperModel = model as? WhisperModel {
                                    Task { await whisperModelManager.downloadModel(whisperModel) }
                                }
                            },
                            editAction: nil
                        )
                    }
                }
            }
        }
        .padding()
    }

    private var emptyModelsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 28))
                .foregroundColor(.secondary.opacity(0.6))
            Text(emptyMessage)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Providers") {
                NotificationCenter.default.post(
                    name: .navigateToDestination,
                    object: nil,
                    userInfo: ["destination": "Providers"]
                )
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 20)
        .background(CardBackground(isSelected: false))
        .cornerRadius(10)
    }

    private var emptyMessage: String {
        switch selectedFilter {
        case .all:
            return "No transcription models available yet. Install a local model or add an API key in Providers."
        case .local:
            return "No local models installed. Download a Whisper or Parakeet model in Providers → Local."
        case .cloud:
            return "No cloud STT providers configured. Add an API key in Providers → Cloud."
        case .custom:
            return "No custom STT providers configured. Add one in Providers → Custom (enable the STT toggle)."
        }
    }

    private func presentDeleteAlert(for model: any TranscriptionModel) {
        if let downloadedModel = whisperModelManager.availableModels.first(where: { $0.name == model.name }) {
            alertTitle = "Delete Model"
            alertMessage = "Are you sure you want to delete '\(downloadedModel.name)'? Use Providers to reinstall it later."
            deleteActionClosure = {
                Task { await whisperModelManager.deleteModel(downloadedModel) }
            }
            isShowingDeleteAlert = true
        }
    }



    private var intelMacWarningBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.orange)

            Text("Local models don't work reliably on Intel Macs")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary.opacity(0.85))

            Spacer()

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedFilter = .cloud
                }
            }) {
                HStack(spacing: 4) {
                    Text("Use Cloud")
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(8)
    }

    private var filteredModels: [any TranscriptionModel] {
        let usableOnly = transcriptionModelManager.allAvailableModels.filter { isUsable($0) }
        switch selectedFilter {
        case .all:
            return usableOnly.filter { transcriptionModelManager.isAvailableOnCurrentOS($0) }
        case .local:
            return usableOnly.filter {
                ($0.provider == .whisper || $0.provider == .nativeApple || $0.provider == .fluidAudio)
                    && transcriptionModelManager.isAvailableOnCurrentOS($0)
            }
        case .cloud:
            return usableOnly.filter { CloudProviderRegistry.provider(for: $0.provider) != nil }
        case .custom:
            return usableOnly.filter { $0.provider == .custom }
        }
    }

    /// True when the model can actually transcribe right now — local model
    /// downloaded, cloud provider key present, custom provider key present.
    /// The Providers tab owns installation/credentials, so models that
    /// aren't usable are hidden here instead of dragging the user through
    /// a half-broken flow.
    private func isUsable(_ model: any TranscriptionModel) -> Bool {
        switch model.provider {
        case .whisper:
            return whisperModelManager.availableModels.contains { $0.name == model.name }
        case .fluidAudio:
            return fluidAudioModelManager.isFluidAudioModelDownloaded(named: model.name)
        case .nativeApple:
            return true
        case .custom:
            if let customModel = model as? CustomCloudModel {
                return APIKeyManager.shared.getCustomModelAPIKey(forModelId: customModel.id) != nil
            }
            return false
        default:
            // Cloud providers — check API key under the provider's raw name.
            return APIKeyManager.shared.hasAPIKey(forProvider: model.provider.rawValue)
        }
    }

}

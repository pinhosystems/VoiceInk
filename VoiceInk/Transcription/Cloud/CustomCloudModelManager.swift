import Combine
import Foundation
import os

/// Thin facade over `CustomProviderManager` that exposes the historical
/// `CustomCloudModel` shape used throughout the STT pipeline
/// (`TranscriptionModelRegistry`, `CloudTranscriptionService`,
/// `ModelManagementView`, backup/restore).
///
/// The underlying storage moved to `CustomProviderManager`, which can hold
/// a single record that offers STT and/or LLM. This facade projects only
/// the STT-capable subset, in the same `CustomCloudModel` Codable shape
/// callers already know.
class CustomCloudModelManager: ObservableObject {
    static let shared = CustomCloudModelManager()

    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "CustomCloudModelManager")
    @Published var customModels: [CustomCloudModel] = []
    private var cancellable: AnyCancellable?

    private init() {
        refresh()
        cancellable = CustomProviderManager.shared.$providers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        // Surface only providers whose STT side is *complete* — toggled on
        // with both URL and model name filled in. A half-configured record
        // (STT box ticked, URL empty) used to leak into AI Models as a
        // ghost option that always failed at request time.
        customModels = CustomProviderManager.shared
            .providers
            .filter { $0.hasUsableSTT }
            .map { Self.synthesize(from: $0) }
    }

    private static func synthesize(from provider: CustomProvider) -> CustomCloudModel {
        CustomCloudModel(
            id: provider.id,
            name: provider.name,
            displayName: provider.name,
            description: provider.summary,
            apiEndpoint: provider.sttEndpointURL,
            modelName: provider.sttModelName,
            isMultilingual: provider.isMultilingual,
            supportedLanguages: LanguageDictionary.forProvider(isMultilingual: provider.isMultilingual)
        )
    }

    // MARK: - Legacy CRUD entrypoints

    func addCustomModel(_ model: CustomCloudModel) {
        let provider = CustomProvider(
            id: model.id,
            name: model.displayName.isEmpty ? model.name : model.displayName,
            summary: model.description,
            offersSTT: true,
            offersLLM: false,
            sttEndpointURL: model.apiEndpoint,
            sttModelName: model.modelName,
            isMultilingual: model.isMultilingualModel,
            supportsStreaming: false
        )
        CustomProviderManager.shared.add(provider)
    }

    func removeCustomModel(withId id: UUID) {
        CustomProviderManager.shared.remove(id: id)
    }

    func updateCustomModel(_ updatedModel: CustomCloudModel) {
        guard var existing = CustomProviderManager.shared.provider(for: updatedModel.id) else { return }
        existing.name = updatedModel.displayName.isEmpty ? updatedModel.name : updatedModel.displayName
        existing.summary = updatedModel.description
        existing.sttEndpointURL = updatedModel.apiEndpoint
        existing.sttModelName = updatedModel.modelName
        existing.isMultilingual = updatedModel.isMultilingualModel
        existing.offersSTT = true
        CustomProviderManager.shared.update(existing)
    }

    func saveCustomModels() {
        // No-op: persistence is owned by CustomProviderManager. Kept for
        // call-site compatibility with the legacy public API.
    }

    // MARK: - Validation (unchanged)

    func validateModel(name: String, displayName: String, apiEndpoint: String, apiKey: String, modelName: String) -> [String] {
        validateModel(name: name, displayName: displayName, apiEndpoint: apiEndpoint, apiKey: apiKey, modelName: modelName, excludingId: nil)
    }

    func validateModel(name: String, displayName: String, apiEndpoint: String, apiKey: String, modelName: String, excludingId: UUID? = nil) -> [String] {
        var errors: [String] = []

        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Name cannot be empty")
        }

        if displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Display name cannot be empty")
        }

        if apiEndpoint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("API endpoint cannot be empty")
        } else if !isValidURL(apiEndpoint) {
            errors.append("API endpoint must be a valid URL")
        }

        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("API key cannot be empty")
        }

        if modelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Model name cannot be empty")
        }

        if customModels.contains(where: { $0.name == name && $0.id != excludingId }) {
            errors.append("A model with this name already exists")
        }

        return errors
    }

    private func isValidURL(_ string: String) -> Bool {
        if let url = URL(string: string) {
            return url.scheme != nil && url.host != nil
        }
        return false
    }
}

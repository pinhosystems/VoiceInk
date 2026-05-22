import Combine
import Foundation
import os

/// Source of truth for user-defined custom providers. Persists a
/// `[CustomProvider]` array to UserDefaults and migrates legacy storage
/// the first time it runs.
///
/// Migration sources (one-shot, idempotent):
///   1. `customCloudModels` UserDefaults JSON — legacy `CustomCloudModel`
///      list. Each becomes a CustomProvider with `offersSTT = true`. IDs
///      are preserved so existing Keychain entries
///      (`customModel_<UUID>_APIKey`) keep working without re-entry.
///   2. `customProviderBaseURL` + `customProviderModel` UserDefaults
///      strings plus the singleton `customAPIKey` Keychain entry. If all
///      three are populated, they become one CustomProvider with
///      `offersLLM = true` and a freshly minted UUID; the Keychain entry
///      is copied to `customModel_<UUID>_APIKey` before the legacy key is
///      cleared.
///
/// After migration, the legacy `customCloudModels` JSON is *kept on disk*
/// so a rollback to an older build can still find it. The legacy LLM
/// strings + Keychain key are cleared because the migrator owns them now.
final class CustomProviderManager: ObservableObject {
    static let shared = CustomProviderManager()

    @Published private(set) var providers: [CustomProvider] = []

    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "CustomProviderManager")
    private let storageKey = "customProvidersV1"
    private let migrationFlagKey = "customProvidersV1.migrated"
    private let userDefaults = UserDefaults.standard

    private init() {
        loadProviders()
        if !userDefaults.bool(forKey: migrationFlagKey) {
            migrateLegacyIfNeeded()
            userDefaults.set(true, forKey: migrationFlagKey)
        }
    }

    // MARK: - CRUD

    func add(_ provider: CustomProvider) {
        providers.append(provider)
        persist()
    }

    func update(_ provider: CustomProvider) {
        guard let index = providers.firstIndex(where: { $0.id == provider.id }) else { return }
        providers[index] = provider
        persist()
    }

    func remove(id: UUID) {
        providers.removeAll { $0.id == id }
        persist()
        APIKeyManager.shared.deleteCustomModelAPIKey(forModelId: id)
    }

    func provider(for id: UUID) -> CustomProvider? {
        providers.first(where: { $0.id == id })
    }

    /// Convenience: providers that offer the given capability.
    func providers(offering capability: ProviderCapability) -> [CustomProvider] {
        providers.filter { $0.capabilities.contains(capability) }
    }

    // MARK: - Persistence

    private func loadProviders() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        do {
            providers = try JSONDecoder().decode([CustomProvider].self, from: data)
        } catch {
            logger.error("Failed to decode CustomProviders: \(error.localizedDescription, privacy: .public)")
            providers = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(providers)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            logger.error("Failed to encode CustomProviders: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Legacy migration

    private func migrateLegacyIfNeeded() {
        var migrated: [CustomProvider] = providers

        // 1. Legacy STT custom models.
        if let legacyData = userDefaults.data(forKey: "customCloudModels"),
           let legacyModels = try? JSONDecoder().decode([CustomCloudModel].self, from: legacyData) {
            for model in legacyModels where !migrated.contains(where: { $0.id == model.id }) {
                migrated.append(CustomProvider(
                    id: model.id,
                    name: model.displayName.isEmpty ? model.name : model.displayName,
                    summary: model.description,
                    offersSTT: true,
                    offersLLM: false,
                    sttEndpointURL: model.apiEndpoint,
                    sttModelName: model.modelName,
                    isMultilingual: model.isMultilingualModel,
                    supportsStreaming: false,
                    llmEndpointURL: "",
                    llmModelName: ""
                ))
            }
            logger.info("Migrated \(legacyModels.count, privacy: .public) legacy CustomCloudModel entries")
        }

        // 2. Legacy single LLM custom singleton.
        let legacyBase = userDefaults.string(forKey: "customProviderBaseURL") ?? ""
        let legacyModel = userDefaults.string(forKey: "customProviderModel") ?? ""
        let legacyKey = KeychainService.shared.getString(forKey: "customAPIKey") ?? ""
        if !legacyBase.isEmpty && !legacyModel.isEmpty && !legacyKey.isEmpty {
            let newID = UUID()
            migrated.append(CustomProvider(
                id: newID,
                name: "Legacy Custom LLM",
                summary: "Migrated from previous singleton Custom provider",
                offersSTT: false,
                offersLLM: true,
                llmEndpointURL: legacyBase,
                llmModelName: legacyModel
            ))
            APIKeyManager.shared.saveCustomModelAPIKey(legacyKey, forModelId: newID)
            _ = KeychainService.shared.delete(forKey: "customAPIKey")
            userDefaults.removeObject(forKey: "customProviderBaseURL")
            userDefaults.removeObject(forKey: "customProviderModel")
            logger.info("Migrated legacy singleton Custom LLM into CustomProvider \(newID.uuidString, privacy: .public)")
        }

        providers = migrated
        persist()
    }
}

import Combine
import Foundation
import os

/// Source of truth for user-defined Local CLI providers. Same multi-
/// instance pattern as `CustomProviderManager`: persists a
/// `[LocalCLIProvider]` array to UserDefaults and migrates the legacy
/// singleton (`localCLICommandTemplate` + `localCLITimeoutSeconds`) on
/// first launch.
///
/// Migration runs once, marked by `localCLIProvidersV1.migrated`. If the
/// legacy command template was non-empty, it becomes a record named
/// "Legacy Local CLI" with the same timeout. Legacy keys are kept in
/// place so a rollback can still read them.
final class LocalCLIProviderManager: ObservableObject {
    static let shared = LocalCLIProviderManager()

    @Published private(set) var providers: [LocalCLIProvider] = []

    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "LocalCLIProviderManager")
    private let storageKey = "localCLIProvidersV1"
    private let migrationFlagKey = "localCLIProvidersV1.migrated"
    private let userDefaults = UserDefaults.standard

    private init() {
        loadProviders()
        if !userDefaults.bool(forKey: migrationFlagKey) {
            migrateLegacyIfNeeded()
            userDefaults.set(true, forKey: migrationFlagKey)
        }
    }

    // MARK: - CRUD

    func add(_ provider: LocalCLIProvider) {
        providers.append(provider)
        persist()
    }

    func update(_ provider: LocalCLIProvider) {
        guard let index = providers.firstIndex(where: { $0.id == provider.id }) else { return }
        providers[index] = provider
        persist()
    }

    func remove(id: UUID) {
        providers.removeAll { $0.id == id }
        persist()
    }

    func provider(for id: UUID) -> LocalCLIProvider? {
        providers.first(where: { $0.id == id })
    }

    var configuredProviders: [LocalCLIProvider] {
        providers.filter { $0.isConfigured }
    }

    // MARK: - Persistence

    private func loadProviders() {
        guard let data = userDefaults.data(forKey: storageKey) else { return }
        do {
            providers = try JSONDecoder().decode([LocalCLIProvider].self, from: data)
        } catch {
            logger.error("Failed to decode LocalCLIProviders: \(error.localizedDescription, privacy: .public)")
            providers = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(providers)
            userDefaults.set(data, forKey: storageKey)
        } catch {
            logger.error("Failed to encode LocalCLIProviders: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Legacy migration

    private func migrateLegacyIfNeeded() {
        let legacyTemplate = userDefaults.string(forKey: LocalCLIService.commandTemplateKey) ?? ""
        guard !legacyTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let legacyTimeout = userDefaults.double(forKey: LocalCLIService.timeoutSecondsKey)
        let timeout = legacyTimeout > 0 ? legacyTimeout : LocalCLIService.defaultTimeoutSeconds

        let migrated = LocalCLIProvider(
            name: "Legacy Local CLI",
            commandTemplate: legacyTemplate,
            timeoutSeconds: timeout
        )
        var current = providers
        if !current.contains(where: { $0.id == migrated.id }) {
            current.append(migrated)
        }
        providers = current
        persist()
        logger.info("Migrated legacy Local CLI command into LocalCLIProvider \(migrated.id.uuidString, privacy: .public)")
    }
}

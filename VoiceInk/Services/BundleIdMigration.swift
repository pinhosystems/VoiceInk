import Foundation
import Security
import os

/// One-shot migration that moves user state from the upstream bundle
/// identifier (`com.prakashjoshipax.VoiceInk`) to the fork identifier
/// (`agabo.dev.voiceink`). Runs once per install, guarded by a flag in
/// the new bundle's standard UserDefaults.
///
/// Three areas are migrated:
/// 1. UserDefaults — copies every user-set key out of the legacy plist
///    at `~/Library/Preferences/com.prakashjoshipax.VoiceInk.plist`.
/// 2. Application Support — renames the on-disk directory holding the
///    SwiftData stores (default/dictionary/stats), Whisper models, and
///    cached audio.
/// 3. Keychain — re-inserts each generic-password item under the new
///    service id. Skipped under LOCAL_BUILD because that path stores
///    secrets in UserDefaults and is covered by step 1.
enum BundleIdMigration {
    private static let logger = Logger(subsystem: "agabo.dev.voiceink", category: "BundleIdMigration")
    private static let completedFlagKey = "BundleIdMigrationV1Completed"
    private static let legacyBundleId = "com.prakashjoshipax.VoiceInk"
    private static let newBundleId = "agabo.dev.voiceink"

    static func runIfNeeded() {
        let standard = UserDefaults.standard
        guard !standard.bool(forKey: completedFlagKey) else { return }

        migrateUserDefaults()
        migrateApplicationSupport()
        #if !LOCAL_BUILD
        migrateKeychain()
        #endif

        standard.set(true, forKey: completedFlagKey)
        logger.notice("Bundle id migration v1 completed (\(legacyBundleId, privacy: .public) → \(newBundleId, privacy: .public))")
    }

    // MARK: - UserDefaults

    private static func migrateUserDefaults() {
        let fm = FileManager.default
        let prefsURL = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/\(legacyBundleId).plist")
        guard fm.fileExists(atPath: prefsURL.path) else { return }

        guard let data = try? Data(contentsOf: prefsURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            logger.warning("Failed to deserialize legacy preferences plist at \(prefsURL.path, privacy: .public)")
            return
        }

        let standard = UserDefaults.standard
        var migrated = 0
        for (key, value) in plist where standard.object(forKey: key) == nil {
            standard.set(value, forKey: key)
            migrated += 1
        }
        logger.notice("Migrated \(migrated, privacy: .public) UserDefaults keys from legacy plist")
    }

    // MARK: - Application Support

    private static func migrateApplicationSupport() {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let oldDir = appSupport.appendingPathComponent(legacyBundleId, isDirectory: true)
        let newDir = appSupport.appendingPathComponent(newBundleId, isDirectory: true)
        guard fm.fileExists(atPath: oldDir.path) else { return }

        if fm.fileExists(atPath: newDir.path) {
            // First launch of the new bundle should leave the new dir
            // unborn — if it exists already we'd clobber whatever already
            // landed there. Leave the legacy dir untouched and let the
            // user reconcile manually.
            logger.warning("Both legacy and new Application Support dirs exist; leaving legacy at \(oldDir.path, privacy: .public)")
            return
        }

        do {
            try fm.moveItem(at: oldDir, to: newDir)
            logger.notice("Moved Application Support: \(oldDir.lastPathComponent, privacy: .public) → \(newDir.lastPathComponent, privacy: .public)")
        } catch {
            logger.error("Failed to move Application Support dir: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Keychain

    #if !LOCAL_BUILD
    private static func migrateKeychain() {
        for syncable in [true, false] {
            migrateKeychainItems(syncable: syncable)
        }
    }

    private static func migrateKeychainItems(syncable: Bool) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: legacyBundleId,
            kSecReturnAttributes as String: kCFBooleanTrue!,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecUseDataProtectionKeychain as String: kCFBooleanTrue!
        ]
        if syncable {
            query[kSecAttrSynchronizable as String] = kCFBooleanTrue
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let items = result as? [[String: Any]] else { return }

        for item in items {
            guard let account = item[kSecAttrAccount as String] as? String,
                  let data = item[kSecValueData as String] as? Data else { continue }

            var addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: newBundleId,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecUseDataProtectionKeychain as String: kCFBooleanTrue!
            ]
            if syncable {
                addQuery[kSecAttrSynchronizable as String] = kCFBooleanTrue
            }

            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            if addStatus == errSecSuccess || addStatus == errSecDuplicateItem {
                logger.info("Migrated keychain item \(account, privacy: .public) (sync=\(syncable, privacy: .public))")
            } else {
                logger.error("Keychain migrate failed for \(account, privacy: .public): status=\(addStatus, privacy: .public)")
            }
        }
    }
    #endif
}

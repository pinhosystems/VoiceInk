import Foundation
import SwiftData
import os

/// Prunes the `troubleshootingLogJSON` field from older transcriptions on
/// a fixed schedule. The transcript text, enhanced text, and metadata are
/// preserved — only the verbose request/response fixture is dropped, since
/// that field is intended for short-term troubleshooting, not long-term
/// archival.
///
/// The retention window is controlled by the
/// `TroubleshootingLogRetentionDays` user default (default 7). A value of
/// `0` disables the sweep entirely.
@MainActor
final class TranscriptionLogRetentionService {

    static let shared = TranscriptionLogRetentionService()

    static let defaultsKey = "TroubleshootingLogRetentionDays"

    /// How often the periodic sweep runs while the app is open. Hourly is
    /// plenty for a multi-day retention window.
    private static let sweepInterval: TimeInterval = 60 * 60

    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "TranscriptionLogRetentionService")
    private var timer: Timer?
    private var modelContext: ModelContext?

    private init() {}

    /// Current retention window in seconds, derived from the user default.
    /// Returns nil when retention is disabled (0).
    private var retentionInterval: TimeInterval? {
        let days = UserDefaults.standard.integer(forKey: Self.defaultsKey)
        guard days > 0 else { return nil }
        return TimeInterval(days) * 24 * 60 * 60
    }

    /// Wire up the sweeper. Idempotent; calling twice keeps the original timer.
    func start(modelContext: ModelContext) {
        guard timer == nil else { return }
        self.modelContext = modelContext

        // Kick off an immediate pass so users opening a fresh app see the
        // retention window already applied to ancient records.
        sweep()

        timer = Timer.scheduledTimer(
            withTimeInterval: Self.sweepInterval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in self?.sweep() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Drops `troubleshootingLogJSON` from every Transcription older than
    /// the user-configured retention window. Other fields are untouched.
    /// No-op when retention is disabled.
    func sweep() {
        guard let modelContext = modelContext,
              let interval = retentionInterval else { return }
        let cutoff = Date().addingTimeInterval(-interval)

        let predicate = #Predicate<Transcription> { transcription in
            transcription.timestamp < cutoff
                && transcription.troubleshootingLogJSON != nil
        }
        let descriptor = FetchDescriptor<Transcription>(predicate: predicate)

        do {
            let stale = try modelContext.fetch(descriptor)
            guard !stale.isEmpty else { return }
            for transcription in stale {
                transcription.troubleshootingLogJSON = nil
            }
            try modelContext.save()
            let days = UserDefaults.standard.integer(forKey: Self.defaultsKey)
            logger.info("Pruned troubleshooting logs from \(stale.count, privacy: .public) transcription(s) older than \(days, privacy: .public) day(s)")
        } catch {
            logger.error("Retention sweep failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Triggered from the Settings UI's "Run Now" control.
    func runManualSweep() {
        sweep()
    }
}

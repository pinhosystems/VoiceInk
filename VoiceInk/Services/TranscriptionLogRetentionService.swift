import Foundation
import SwiftData
import os

/// Prunes the `troubleshootingLogJSON` field from older transcriptions on
/// a fixed schedule. The transcript text, enhanced text, and metadata are
/// preserved — only the verbose request/response fixture is dropped after
/// seven days, since that field is intended for short-term troubleshooting,
/// not long-term archival.
@MainActor
final class TranscriptionLogRetentionService {

    static let shared = TranscriptionLogRetentionService()

    static let retentionInterval: TimeInterval = 7 * 24 * 60 * 60   // 7 days
    /// How often the periodic sweep runs while the app is open. Hourly is
    /// plenty for a 7-day retention window.
    private static let sweepInterval: TimeInterval = 60 * 60

    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "TranscriptionLogRetentionService")
    private var timer: Timer?
    private var modelContext: ModelContext?

    private init() {}

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
    /// `retentionInterval`. Other fields are untouched.
    func sweep() {
        guard let modelContext = modelContext else { return }
        let cutoff = Date().addingTimeInterval(-Self.retentionInterval)

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
            logger.info("Pruned troubleshooting logs from \(stale.count, privacy: .public) transcription(s) older than 7 days")
        } catch {
            logger.error("Retention sweep failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

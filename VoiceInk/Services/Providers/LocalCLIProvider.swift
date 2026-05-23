import Foundation

/// User-defined Local CLI configuration. Same multi-instance shape as
/// `CustomProvider`: each record carries a friendly name and the shell
/// command template + timeout the user wants invoked for enhancement.
/// Persisted by `LocalCLIProviderManager`.
struct LocalCLIProvider: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var commandTemplate: String
    var timeoutSeconds: Double

    init(
        id: UUID = UUID(),
        name: String,
        commandTemplate: String = "",
        timeoutSeconds: Double = LocalCLIService.defaultTimeoutSeconds
    ) {
        self.id = id
        self.name = name
        self.commandTemplate = commandTemplate
        self.timeoutSeconds = timeoutSeconds
    }

    var isConfigured: Bool {
        !commandTemplate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

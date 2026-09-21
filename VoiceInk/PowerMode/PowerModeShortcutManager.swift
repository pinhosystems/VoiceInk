import Foundation
import KeyboardShortcuts

@MainActor
class PowerModeShortcutManager {
    private weak var engine: VoiceInkEngine?
    private var registeredPowerModeIds: Set<UUID> = []

    init(engine: VoiceInkEngine) {
        self.engine = engine

        setupPowerModeHotkeys()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(powerModeConfigurationsDidChange),
            name: NSNotification.Name("PowerModeConfigurationsDidChange"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func powerModeConfigurationsDidChange() {
        Task { @MainActor in
            setupPowerModeHotkeys()
        }
    }

    private func setupPowerModeHotkeys() {
        // Shortcut presence lives in the KeyboardShortcuts store (name
        // "powerMode_<uuid>"), not on the config — the old `hotkeyShortcut`
        // string was only a "configured" sentinel that could desync.
        let currentIds = Set(PowerModeManager.shared.configurations.map { $0.id })

        // Clear bindings for deleted configs
        let idsToRemove = registeredPowerModeIds.subtracting(currentIds)
        idsToRemove.forEach { id in
            KeyboardShortcuts.setShortcut(nil, for: .powerMode(id: id))
            registeredPowerModeIds.remove(id)
        }

        // Register a handler for every config; the handler is a no-op
        // until the user actually records a shortcut for that name.
        PowerModeManager.shared.configurations.forEach { config in
            guard !registeredPowerModeIds.contains(config.id) else { return }

            KeyboardShortcuts.onKeyUp(for: .powerMode(id: config.id)) { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    await self.handlePowerModeHotkey(powerModeId: config.id)
                }
            }

            registeredPowerModeIds.insert(config.id)
        }
    }

    private func handlePowerModeHotkey(powerModeId: UUID) async {
        guard let engine = engine,
              canProcessHotkeyAction(engine: engine) else { return }

        guard let config = PowerModeManager.shared.getConfiguration(with: powerModeId) else {
            return
        }

        if config.hotkeySwitchesOnly {
            PowerModeManager.shared.setActiveConfiguration(config)
            await PowerModeSessionManager.shared.beginSession(with: config)
            return
        }

        await engine.recorderUIManager?.toggleMiniRecorder(powerModeId: powerModeId)
    }

    private func canProcessHotkeyAction(engine: VoiceInkEngine) -> Bool {
        engine.recordingState != .transcribing &&
        engine.recordingState != .enhancing &&
        engine.recordingState != .busy
    }
}

// MARK: - PowerMode Keyboard Shortcut Names
extension KeyboardShortcuts.Name {
    static func powerMode(id: UUID) -> Self {
        Self("powerMode_\(id.uuidString)")
    }
}

import SwiftUI

/// Inline banner shown at the top of the Enhancement screen whenever a Power
/// Mode session is overriding the global enhancement state. Without this the
/// user could open the screen, see e.g. AI Enhancement OFF, and be confused
/// because the visible state belongs to the active Power Mode rather than the
/// global default — which the user actually set differently a moment ago.
///
/// The banner self-hides when no Power Mode is active. The Clear button calls
/// PowerModeManager.setActiveConfiguration(nil) plus
/// PowerModeSessionManager.endSession so the global state restores from the
/// session snapshot.
struct EnhancementPowerModeBanner: View {
    @ObservedObject private var powerModeManager = PowerModeManager.shared

    var body: some View {
        if let config = powerModeManager.activeConfiguration {
            HStack(spacing: 10) {
                Text(config.emoji)
                    .font(.system(size: 22))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Power Mode active: \(config.name)")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Settings below reflect this profile, not your global defaults. Clear to restore.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button("Clear") {
                    powerModeManager.setActiveConfiguration(nil)
                    Task {
                        await PowerModeSessionManager.shared.endSession()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor.opacity(0.25), lineWidth: 0.5)
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
    }
}

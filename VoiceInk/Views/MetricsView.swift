import SwiftUI
import SwiftData
import Charts
import KeyboardShortcuts

struct MetricsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @StateObject private var licenseViewModel = LicenseViewModel()

    var body: some View {
        VStack {
            // Trial / trial-expired banners removed in the fork — they
            // promoted the upstream paid product ("Upgrade to continue
            // using VoiceInk") which doesn't apply here. MetricsContent
            // itself still receives the license state because downstream
            // sections gate optional UI on it.
            MetricsContent(
                modelContext: modelContext,
                licenseState: licenseViewModel.licenseState
            )
        }
        .background(Color(.controlBackgroundColor))
    }
}

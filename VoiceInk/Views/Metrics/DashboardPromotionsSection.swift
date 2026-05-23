import SwiftUI

/// Dashboard promotion banners were upstream commerce surfaces — a
/// "30% off VoiceInk Pro" share-to-unlock card during trial, plus an
/// affiliate-program card for activated users. Both routed to
/// tryvoiceink.com, which the fork has no relationship with.
///
/// Kept as a stub view with the same call signature so MetricsContent
/// doesn't have to change. Reintroduce real content here only when the
/// fork has its own promotional channels.
struct DashboardPromotionsSection: View {
    let licenseState: LicenseViewModel.LicenseState

    var body: some View {
        EmptyView()
    }
}

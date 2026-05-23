import Foundation
import SwiftUI
import AppKit

/// Help / support entry point for the fork.
///
/// The upstream `EmailSupport` opened a mailto: to support@tryvoiceink.com
/// and embedded a link to tryvoiceink.com/common-issues — both addresses
/// the fork has no relationship with. Replaced with a redirect to the
/// fork's GitHub issues page so users land somewhere actionable.
///
/// The type name and `openSupportEmail()` method name are preserved for
/// back-compat with existing callers (MenuBarView's "Help and Support"
/// button); the implementation just opens a URL instead of composing a
/// mail message.
struct EmailSupport {
    private static let issuesURL = URL(string: "https://github.com/pinhosystems/VoiceInk/issues/new")!

    static func openSupportEmail() {
        // Copy system info to the clipboard so the user can paste it
        // into the new issue's body if they want — matches the upstream
        // behavior of pre-populating system info, just via clipboard
        // instead of a mailto body.
        SystemInfoService.shared.copySystemInfoToClipboard()
        NSWorkspace.shared.open(Self.issuesURL)
    }
}

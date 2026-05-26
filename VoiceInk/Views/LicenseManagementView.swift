import SwiftUI

/// "About" screen for the pinhosystems/VoiceInk fork.
///
/// The upstream Beingpax/VoiceInk ships this surface as a paid-upgrade
/// funnel (Polar purchase page, license-key activation, customer
/// portal, Buy Me a Coffee tip jar). The fork neither sells nor
/// validates anything against upstream commerce — so the whole tab
/// was repaginated as a neutral About screen.
///
/// Layout follows the "About this Mac" mental model: large icon at the
/// top, a centered name + version chip, a single elegant content panel
/// with hairline separators between sub-sections, and a subtle credit
/// footer. No drop shadows or accent buttons compete with the rest of
/// the app's chrome.
struct LicenseManagementView: View {
    @Environment(\.colorScheme) private var colorScheme

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

    private static let forkRepoURL   = URL(string: "https://github.com/pinhosystems/VoiceInk")!
    private static let forkIssuesURL = URL(string: "https://github.com/pinhosystems/VoiceInk/issues")!

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                hero
                    .padding(.top, 56)
                    .padding(.bottom, 40)

                contentPanel
                    .frame(maxWidth: 560)

                credit
                    .padding(.top, 24)
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 18) {
            AppIconView()

            VStack(spacing: 8) {
                Text("VoiceInk")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primary)

                versionChip

                Text("Local-first dictation with cloud STT and LLM enhancement.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
                    .frame(maxWidth: 360)
            }
        }
    }

    private var versionChip: some View {
        HStack(spacing: 6) {
            Text("v\(appVersion)")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.primary)
            Text("·")
                .foregroundColor(.secondary.opacity(0.4))
            Text("build \(buildNumber)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule().fill(Color.primary.opacity(0.06))
        )
        .overlay(
            Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    // MARK: - Content panel

    private var contentPanel: some View {
        VStack(spacing: 0) {
            aboutBlock
            hairline
            linksBlock
            hairline
            buildInfoBlock
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }

    private var hairline: some View {
        Divider().opacity(0.5)
    }

    private var aboutBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            blockHeader(icon: "info.circle", title: "About this build")
            Text("Personal fork maintained at pinhosystems/VoiceInk. It does not sell licenses, validate keys against any commerce backend, or carry the upstream paid tier.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    private var linksBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            blockHeader(icon: "link", title: "Links")
            VStack(spacing: 2) {
                linkRow(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: "Repository",
                    subtitle: "pinhosystems/VoiceInk",
                    url: Self.forkRepoURL
                )
                linkRow(
                    icon: "exclamationmark.bubble",
                    title: "Report an issue",
                    subtitle: "pinhosystems/VoiceInk/issues",
                    url: Self.forkIssuesURL
                )
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    private var buildInfoBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            blockHeader(icon: "wrench.and.screwdriver", title: "Build")
            VStack(alignment: .leading, spacing: 4) {
                buildInfoRow(label: "macOS",     value: ProcessInfo.processInfo.operatingSystemVersionString)
                buildInfoRow(label: "Arch",      value: hostArchitecture)
                buildInfoRow(label: "Bundle",    value: Bundle.main.bundleIdentifier ?? "—")
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
    }

    // MARK: - Building blocks

    private func blockHeader(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 18, height: 18)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(.secondary)
                .tracking(0.8)
        }
    }

    private func linkRow(icon: String, title: String, subtitle: String, url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    private func buildInfoRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.primary.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Credit footer

    /// Upstream attribution sits below the content panel as a quiet
    /// footer. GPL v3 compliance comes from the LICENSE in the repo
    /// and the public commit history — this is courtesy, not a
    /// requirement, so it gets the smallest visual weight available.
    private var credit: some View {
        Text("Originally derived from Beingpax/VoiceInk")
            .font(.system(size: 10))
            .foregroundStyle(.secondary.opacity(0.6))
    }

    // MARK: - Helpers

    private var hostArchitecture: String {
        #if arch(arm64)
        return "arm64 (Apple Silicon)"
        #elseif arch(x86_64)
        return "x86_64 (Intel)"
        #else
        return "unknown"
        #endif
    }
}

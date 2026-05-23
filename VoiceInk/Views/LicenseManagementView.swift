import SwiftUI

/// "About" screen for the pinhosystems/VoiceInk fork.
///
/// The upstream Beingpax/VoiceInk ships this surface as a paid-upgrade
/// funnel (Polar purchase page, license-key activation, customer
/// portal, Buy Me a Coffee tip jar, ProductHunt tagline). The fork
/// neither sells nor validates anything against upstream commerce — so
/// the whole tab was repaginated to a neutral About + links section.
struct LicenseManagementView: View {
    @Environment(\.colorScheme) private var colorScheme
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

    private static let forkRepoURL    = URL(string: "https://github.com/pinhosystems/VoiceInk")!
    private static let forkIssuesURL  = URL(string: "https://github.com/pinhosystems/VoiceInk/issues")!
    private static let upstreamURL    = URL(string: "https://github.com/Beingpax/VoiceInk")!

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                heroSection
                aboutCard
                linksCard
            }
            .padding(32)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var heroSection: some View {
        VStack(spacing: 18) {
            AppIconView()

            HStack(alignment: .lastTextBaseline, spacing: 8) {
                Text("VoiceInk")
                    .font(.system(size: 32, weight: .bold))
                Text("v\(appVersion)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Text("Personal fork. Local-first dictation with cloud STT and LLM enhancement.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("About this build", icon: "info.circle.fill")

            Text("This is a personal fork maintained at pinhosystems/VoiceInk. It does not sell licenses, validate keys against any commerce backend, or carry the upstream paid tier. All features ship enabled to the developer; the upstream paid product is unrelated to this build.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(2)

            Divider().padding(.vertical, 4)

            Text("Originally derived from Beingpax/VoiceInk by Prakash Joshi Pax. Credit and gratitude for the upstream work that made this fork possible.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineSpacing(2)
        }
        .padding(24)
        .background(CardBackground(isSelected: false))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }

    private var linksCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Links", icon: "link.circle.fill")

            linkRow(
                icon: "chevron.left.forwardslash.chevron.right",
                title: "Fork repository",
                subtitle: "pinhosystems/VoiceInk",
                url: Self.forkRepoURL
            )

            linkRow(
                icon: "exclamationmark.bubble.fill",
                title: "Report an issue",
                subtitle: "pinhosystems/VoiceInk/issues",
                url: Self.forkIssuesURL
            )

            linkRow(
                icon: "arrow.up.right.square.fill",
                title: "Upstream project",
                subtitle: "Beingpax/VoiceInk",
                url: Self.upstreamURL
            )
        }
        .padding(24)
        .background(CardBackground(isSelected: false))
        .shadow(color: .black.opacity(0.05), radius: 10)
    }

    private func sectionTitle(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.accentColor)
            Text(text)
                .font(.system(size: 14, weight: .semibold))
        }
    }

    private func linkRow(icon: String, title: String, subtitle: String, url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.accentColor)
                    .frame(width: 24)

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
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )
        }
        .buttonStyle(.plain)
    }
}

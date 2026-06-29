import SwiftUI

struct CompactHeroSection: View {
    let icon: String
    let title: String
    let description: String
    var maxDescriptionWidth: CGFloat? = nil

    // Slimmed to a plain left-aligned title + subtitle. The decorative icon
    // and centered splash layout were preamble weight on task-focused
    // screens; the screen's own title carries identity. `icon` is retained in
    // the signature so call sites stay unchanged.
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
            Text(description)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: maxDescriptionWidth, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
    }
}

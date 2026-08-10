import SwiftUI

/// Top-bar bracelet chip — dot shows linked vs recently detected on the band.
struct BraceletToolbarButton: View {
    @Environment(\.layoutMetrics) private var layout
    @ObservedObject var link: BraceletLinkStore

    var body: some View {
        HStack(spacing: layout.s(5)) {
            Circle()
                .fill(dotColor)
                .frame(width: layout.statusDot, height: layout.statusDot)
                .shadow(color: link.isNearby ? Color.green.opacity(0.35) : .clear, radius: layout.s(3))
            Image(systemName: "wave.3.right")
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(link.isLinked ? AppTheme.accent : AppTheme.muted)
        .accessibilityLabel(accessibilityLabel)
    }

    private var dotColor: Color {
        if link.isNearby { return Color(red: 0.09, green: 0.64, blue: 0.29) }
        if link.isLinked { return AppTheme.accent.opacity(0.75) }
        return AppTheme.muted.opacity(0.35)
    }

    private var accessibilityLabel: String {
        if link.isNearby { return "Bracelet connected" }
        if link.isLinked { return "Bracelet linked" }
        return "Bracelet setup"
    }
}

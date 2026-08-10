import SwiftUI

/// Floating flat-white tab bar from the Claude artifact design session.
struct CustomTabBar: View {
    @Environment(\.layoutMetrics) private var layout
    @Binding var tab: OwnerTab

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color(red: 0.9, green: 0.9, blue: 0.9))
            HStack(spacing: 0) {
                tabItem(icon: "person.fill", label: "RedMed", tab: .myID)
                tabItem(icon: "phone.fill", label: "911", tab: .find911)
                tabItem(icon: "cross.case.fill", label: "Aid", tab: .aid)
                tabItem(icon: "wave.3.right", label: "NFC", tab: .nfc)
            }
            .padding(.top, layout.s(4))

            Capsule()
                .fill(AppTheme.ink.opacity(0.18))
                .frame(width: layout.s(134), height: layout.s(5))
                .padding(.top, layout.s(4))
                .padding(.bottom, layout.s(8))
        }
        .background(Color.white)
    }

    private func tabItem(icon: String, label: String, tab target: OwnerTab) -> some View {
        let isOn = tab == target
        return Button {
            tab = target
        } label: {
            VStack(spacing: layout.s(2)) {
                Image(systemName: icon)
                    .font(.system(size: layout.s(22)))
                    .foregroundStyle(isOn ? AppTheme.accent : AppTheme.muted)
                    .padding(.horizontal, layout.s(16))
                    .padding(.vertical, layout.s(5))
                    .background(
                        RoundedRectangle(cornerRadius: layout.s(14), style: .continuous)
                            .fill(isOn ? AppTheme.accent.opacity(0.05) : Color.clear) // lowered highlight
                    )
                Text(label)
                    .font(.system(size: layout.s(10), weight: isOn ? .semibold : .medium))
                    .foregroundStyle(isOn ? AppTheme.accent : AppTheme.muted)
                    .kerning(-0.1)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, layout.s(6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

enum OwnerTab: Hashable {
    case myID, find911, aid, nfc
}

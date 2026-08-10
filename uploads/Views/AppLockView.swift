import SwiftUI

/// Lock screen kept for previews — Face ID gates **edits only** in
/// `EditProfileView`, not app launch.
struct AppLockView: View {
    @Environment(\.layoutMetrics) private var layout

    let availability: BiometricGate.Availability
    let isAuthenticating: Bool
    let failed: Bool
    let onUnlock: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: layout.spaceXL) {
                Spacer(minLength: layout.space2XL)

                BrandMark(size: .hero)

                VStack(spacing: layout.spaceSM) {
                    Image(systemName: iconName)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                        .padding(.bottom, layout.spaceXS)
                        .accessibilityHidden(true) // meaning is carried by the text below

                    Text("RedMed is locked")
                        .font(.title2.bold())
                        .foregroundStyle(AppTheme.ink)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, layout.spaceLG)
                }
                .accessibilityElement(children: .combine)

                if failed {
                    Text("Couldn't verify it's you. Try again.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                        .accessibilityAddTraits(.updatesFrequently)
                }

                Spacer(minLength: layout.space2XL)
            }
            .padding(.horizontal, layout.space2XL)
            .padding(.top, layout.space2XL)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.visible, axes: .vertical)
        .background(AppTheme.pageBg)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomBar
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility3) // cap runaway scaling from breaking the button row
    }

    private var bottomBar: some View {
        VStack(spacing: layout.spaceMD) {
            Button {
                onUnlock()
            } label: {
                if isAuthenticating {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    Text(unlockLabel)
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(PrimaryButtonStyle(prominent: true))
            .disabled(isAuthenticating)
            .accessibilityLabel(isAuthenticating ? "Unlocking" : unlockLabel)
            .accessibilityHint("Double tap if RedMed didn't prompt automatically.")

            Text("Your medical profile stays on this device only. Anyone scanning your NFC card or emergency link still sees it — locking the app does not affect that.")
                .font(.caption2)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, layout.spaceLG)
        .padding(.top, layout.spaceSM)
        .padding(.bottom, layout.spaceMD)
        .background(AppTheme.pageBg)
    }

    private var iconName: String { availability.iconSystemName }
    private var subtitle: String { availability.lockSubtitle }
    private var unlockLabel: String { availability.lockUnlockLabel }
}

#Preview {
    AppLockView(availability: .faceID, isAuthenticating: false, failed: false, onUnlock: {})
        .withLayoutMetrics()
}

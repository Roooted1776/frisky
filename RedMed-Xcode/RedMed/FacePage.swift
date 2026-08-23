import SwiftUI

/// Lock retry page after Face ID cancel / mismatch. Title **Face**.
/// Single **Proceed** CTA. Cream user-page fill. Not a dock over LockEntryPage.
/// Static medical mark — never gates Face ID.
struct FacePage: View {
    var screenCaptured: Bool
    var biometryFailed: Bool
    var profileLoadFailed: Bool
    var isAuthenticating: Bool
    var onProceed: () -> Void

    var body: some View {
        ZStack {
            Color.redmedBg
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                Text("Face")
                    .font(RedMedChrome.navTitleFont)
                    .foregroundColor(.redmedDark)
                    .frame(maxWidth: .infinity)
                    .frame(height: RedMedChrome.modalBarHeight)
                    .accessibilityAddTraits(.isHeader)
                Rectangle()
                    .fill(Color.redmedDivider)
                    .frame(height: 1)

                Spacer(minLength: 0)
                LockMedGlyph()
                    .frame(
                        width: RedMedChrome.unlockFrameSize,
                        height: RedMedChrome.unlockFrameSize
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)

                VStack(spacing: 14) {
                    if screenCaptured {
                        Text("Screen sharing is on. Unlock with Face ID — your profile stays hidden on the share until you stop sharing.")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.redmedMuted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if isAuthenticating {
                        Text("Looking for Face ID…")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.redmedMuted)
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.updatesFrequently)
                    } else if biometryFailed {
                        Text("Couldn't verify it's you. Try again.")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.redmedAccent)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if profileLoadFailed {
                        Text("Couldn't load your profile. Try again.")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.redmedAccent)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    UnlockScreenButton(
                        title: "Proceed",
                        disabled: isAuthenticating,
                        accessibilityHintText: "Face ID or Touch ID"
                    ) {
                        onProceed()
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 36)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Face")
    }
}

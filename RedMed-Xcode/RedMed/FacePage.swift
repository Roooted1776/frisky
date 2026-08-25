import SwiftUI

/// Lock retry page after Face ID cancel / mismatch. Title **Face**.
/// Single CTA — **Proceed** normally, **Open Settings** when
/// `unavailableReason` is set (retrying evaluatePolicy the same way can't
/// fix a lockout / not-enrolled / no-passcode state; no sheet even shows
/// for those). Cream user-page fill with the brand mark. Not a dock over
/// LockEntryPage. The mark is decorative — never gates Face ID.
struct FacePage: View {
    var screenCaptured: Bool
    var biometryFailed: Bool
    var unavailableReason: BiometricAuth.UnavailableReason?
    var profileLoadFailed: Bool
    var notInteractive: Bool
    var isAuthenticating: Bool
    var onProceed: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        ZStack {
            Color.redmedBg
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
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
                    } else if let unavailableReason {
                        Text(unavailableReason.message)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.redmedAccent)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
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
                    } else if notInteractive {
                        Text("Couldn't open Face ID. Try again.")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.redmedAccent)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let unavailableReason {
                        UnlockScreenButton(
                            title: "Open Settings",
                            accessibilityHintText: unavailableReason.message
                        ) {
                            onOpenSettings()
                        }
                    } else {
                        UnlockScreenButton(
                            title: "Proceed",
                            disabled: isAuthenticating,
                            accessibilityHintText: "Face ID or Touch ID"
                        ) {
                            onProceed()
                        }
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

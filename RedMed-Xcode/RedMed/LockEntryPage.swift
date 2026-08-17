import SwiftUI

/// Front-of-app page — Face ID on user-page cream, then Main.
///
/// No glyph, no Help, no 911 / Aid / NFC. Flat `Color.redmedBg` (`#fff7f7`),
/// same fill as the RedMed user tab. Unlock dock only after Face ID cancel /
/// mismatch. Auth stays in `OwnerAppLock`.
struct LockEntryPage: View {
    var showsRetryDock: Bool
    var screenCaptured: Bool
    var biometryFailed: Bool
    var profileLoadFailed: Bool
    var showUnlockControl: Bool
    var isAuthenticating: Bool
    var onUnlock: () -> Void

    var body: some View {
        ZStack {
            Color.redmedBg
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            if showsRetryDock {
                retryDock
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("RedMed is locked")
    }

    /// Unlock after cancel / mismatch (hidden on first Face ID prompt).
    private var retryDock: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 16) {
                if screenCaptured {
                    Text("Screen sharing is on — unlock with passcode. Profile stays hidden on the share until you stop sharing.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if biometryFailed {
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

                if showUnlockControl {
                    unlockButton
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity)
            .background(Color.redmedBg)
            .padding(.horizontal, 14)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.identity)
    }

    private var unlockButton: some View {
        Button {
            RedMedHaptics.medium()
            onUnlock()
        } label: {
            Group {
                if isAuthenticating {
                    Text("Unlocking")
                        .font(.system(size: 16, weight: .bold))
                        .accessibilityLabel("Unlocking with Face ID")
                } else {
                    Text("Unlock")
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: RedMedChrome.unlockButtonRadius, style: .continuous)
                    .fill(Color.redmedAccent)
            }
        }
        .buttonStyle(RedMedPressStyle(haptic: nil))
        .disabled(isAuthenticating)
        .accessibilityHint("Face ID, Touch ID, or passcode")
    }
}

import SwiftUI

/// Front-of-app lock page — Face ID, then Main.
///
/// Static user-page cream (`Color.redmedBg` / `#fff7f7`). No LockOpen clip, no
/// wash. Glyph under the Face ID sheet; Unlock dock only after cancel /
/// mismatch. Auth logic stays in `OwnerAppLock` so this page can be rewritten
/// without touching the gate.
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

            if !showsRetryDock {
                LockMedGlyph()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .offset(y: -28)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            if showsRetryDock {
                retryDock
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("RedMed is locked")
    }

    /// Status + Unlock after cancel / mismatch (hidden on first Face ID prompt).
    private var retryDock: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.redmedDark.opacity(0.14))
                    .frame(width: 36, height: 4)
                    .padding(.bottom, 2)

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
                } else if showUnlockControl {
                    Text("Unlock to open RedMed")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.redmedDark.opacity(0.78))
                        .multilineTextAlignment(.center)
                }

                if showUnlockControl {
                    unlockButton
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity)
            .background { dockBackground }
            .padding(.horizontal, 14)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.identity)
    }

    private var dockBackground: some View {
        let shape = RoundedRectangle(cornerRadius: RedMedChrome.unlockDockRadius, style: .continuous)
        return shape
            .fill(Color.redmedSurface)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.redmedDivider
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)
    }

    private var unlockButton: some View {
        Button {
            RedMedHaptics.medium()
            onUnlock()
        } label: {
            Group {
                if isAuthenticating {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Unlocking")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .accessibilityLabel("Unlocking with Face ID")
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Unlock")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: RedMedChrome.unlockButtonRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1, green: 0.447, blue: 0.537).opacity(0.75),
                                Color.redmedAccent.opacity(0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: RedMedChrome.unlockButtonRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.32), lineWidth: 1)
                    }
                    .shadow(color: RedMedChrome.accentShadow, radius: 12, y: 6)
            }
        }
        .buttonStyle(RedMedPressStyle(haptic: nil))
        .disabled(isAuthenticating)
        .accessibilityHint("Face ID, Touch ID, or passcode")
    }
}

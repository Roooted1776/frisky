import SwiftUI

/// Front-of-app shell while Face ID / passcode presents.
///
/// Cream + medical heart mark + "Before you continue" — same field as
/// `UILaunchScreen` / LaunchAck, so start is not a blank cream hang.
/// Face ID is still the only interactive UI. After cancel, `FacePage`.
struct LockEntryPage: View {
    var body: some View {
        ZStack {
            Color.redmedBg
                .ignoresSafeArea()
            VStack(spacing: 14) {
                LockMedGlyph(size: RedMedChrome.unlockFrameSize)
                Text("Before you continue")
                    .font(.system(size: 22, weight: .bold))
                    .kerning(-0.4)
                    .foregroundColor(.redmedDark)
                    .multilineTextAlignment(.center)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("RedMed is locked")
    }
}

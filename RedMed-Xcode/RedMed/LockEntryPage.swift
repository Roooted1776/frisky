import SwiftUI

/// Front-of-app shell while Face ID / passcode presents.
///
/// Cream + medical heart mark — same field as `UILaunchScreen`, so start
/// is not a blank cream hang. Face ID is still the only interactive UI.
/// After cancel, `FacePage`.
struct LockEntryPage: View {
    var body: some View {
        ZStack {
            Color.redmedBg
                .ignoresSafeArea()
            LockMedGlyph(size: RedMedChrome.unlockFrameSize)
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("RedMed is locked")
    }
}

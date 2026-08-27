import SwiftUI

/// Front-of-app shell while Face ID / passcode presents.
///
/// Flat cream only — same as `UILaunchScreen`. No logo, no spinner, no
/// hangtime chrome. Face ID is the only UI. After cancel, `FacePage`.
struct LockEntryPage: View {
    var body: some View {
        Color.redmedBg
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel("RedMed is locked")
    }
}

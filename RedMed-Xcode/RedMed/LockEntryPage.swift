import SwiftUI

/// Front-of-app page — first Face ID only, then Main.
///
/// Cream user-page fill. No hanging mark, no Unlock retry, no Help, no other
/// tabs. Face ID is the only chrome.
struct LockEntryPage: View {
    var body: some View {
        Color.redmedBg
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel("RedMed is locked")
    }
}

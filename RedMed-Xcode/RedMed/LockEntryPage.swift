import SwiftUI

/// Front-of-app page — first Face ID only, then Main.
///
/// Cream user-page fill with the brand mark. No Unlock retry, no Help, no
/// other tabs. Face ID is the only chrome.
struct LockEntryPage: View {
    var body: some View {
        ZStack {
            Color.redmedBg
                .ignoresSafeArea()

            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("RedMed is locked")
    }
}

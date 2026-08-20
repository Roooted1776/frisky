import SwiftUI

/// Front-of-app page — first Face ID only, then Main.
///
/// Cream user-page fill + static medical mark. No Unlock retry, no Help, no other
/// tabs. Mark never gates Face ID.
struct LockEntryPage: View {
    var body: some View {
        ZStack {
            Color.redmedBg
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            LockMedGlyph()
                .frame(width: RedMedChrome.unlockGlyphSize, height: RedMedChrome.unlockGlyphSize)
                .offset(y: -28)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("RedMed is locked")
    }
}

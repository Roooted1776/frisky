import SwiftUI

/// Front-of-app page — first Face ID only, Higgs `FaceIDFrame` clip, then Main.
///
/// Cream user-page fill. No Unlock retry, no Help, no other tabs. Clip never
/// gates Face ID. Missing file / Reduce Motion / Low Power = cream only.
struct LockEntryPage: View {
    var playing: Bool

    var body: some View {
        ZStack {
            Color.redmedBg
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            if FaceIDFrameClip.shouldPlay {
                FaceIDFrameVideo(playing: playing)
                    .frame(width: RedMedChrome.unlockGlyphSize, height: RedMedChrome.unlockGlyphSize)
                    .offset(y: -28)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("RedMed is locked")
    }
}

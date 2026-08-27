import SwiftUI

/// Front-of-app page — first Face ID only, then Main.
///
/// Cream user-page fill with the brand mark. No Unlock retry, no Help, no
/// other tabs. Face ID is the only chrome.
struct LockEntryPage: View {
    // Face ID's system sheet is usually up well before this — only shown if
    // the sheet is slow to present, so a normal launch never sees it.
    @State private var showActivity = false

    var body: some View {
        ZStack {
            Color.redmedBg

            VStack(spacing: 16) {
                Image("BrandLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)

                if showActivity {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .transition(.opacity)
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("RedMed is locked")
        .task {
            // 280ms — long enough that a fast Face ID sheet never shows this,
            // short enough that a slow present doesn't read as a hung cream page
            // (was 1.2s, which left the lock looking frozen).
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.15)) {
                showActivity = true
            }
        }
    }
}

import SwiftUI

@main
struct RedMedApp: App {
    @StateObject private var profile = ProfileData()

    var body: some Scene {
        WindowGroup {
            PrivacySnapshotGuard {
                LaunchRoot()
            }
            .environmentObject(profile)
            .background(Color.redmedBg.ignoresSafeArea())
            .background(CreamWindowBackground())
            .preferredColorScheme(.light)
            .task {
                // Register snapshot observers only. Do not warm WKWebView here —
                // that competed with the first Main frame and left cream on screen.
                SnapshotSafeCover.activate()
                OwnerLockPresentation.setLocked(false)
                OwnerLockPresentation.holdSwitcherCover = false
                SnapshotSafeCover.shared.reveal()
            }
            .onOpenURL { url in
                if (url.scheme ?? "").lowercased() == "redmed",
                   (url.host ?? "").lowercased() == "nfc" {
                    NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { _ in }
        }
    }
}

/// Cold start: Before you continue, then Main after Agree this process.
/// Same session stays in Main. No cream lock page in front. Face ID still gates Edit.
private struct LaunchRoot: View {
    var body: some View {
        ConsentGateView { Main() }
            .onAppear {
                OwnerLockPresentation.setLocked(false)
                OwnerLockPresentation.holdSwitcherCover = false
                SnapshotSafeCover.shared.reveal()
            }
    }
}

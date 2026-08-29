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
                OwnerLockPresentation.setLocked(true)
                OwnerLockPresentation.holdSwitcherCover = true
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

/// System Face ID first. After unlock: acknowledgment (first launch /
/// policy bump), then Main. Later opens and returns: Face ID, then Main.
/// Passerby tapper never goes through this root.
private struct LaunchRoot: View {
    var body: some View {
        OwnerAppLock { ConsentGateView { Main() } }
    }
}

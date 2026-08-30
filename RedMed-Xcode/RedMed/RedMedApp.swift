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
                // Snapshot observers only. Do not warm WKWebView or read
                // tapper.html here — that raced the first Main frame.
                // Do not restore PHI here — OwnerAppLock adopts after Face ID.
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

/// Face ID (system sheet on cream) then Before you continue / Main.
/// No heart, no Proceed. Passerby tapper is not in this tree.
private struct LaunchRoot: View {
    var body: some View {
        OwnerAppLock {
            ConsentGateView { Main() }
        }
    }
}

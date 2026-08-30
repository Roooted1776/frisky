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
                // Snapshot observers + string-only tapper.html warm. Do not
                // construct a WKWebView here — that raced the first Main frame.
                SnapshotSafeCover.activate()
                OwnerLockPresentation.setLocked(false)
                OwnerLockPresentation.holdSwitcherCover = false
                SnapshotSafeCover.shared.reveal()
                PasserbyHTMLCardView.scheduleShellWarmOnce()
                await profile.restoreOnLaunch()
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

/// First open: Before you continue with Agree on screen. Later opens: Main.
/// No cream lock page in front. Face ID still gates Edit.
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

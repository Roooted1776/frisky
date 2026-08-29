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
                SnapshotSafeCover.activate()
                // After first frame — do not sleep 300ms on the launch path.
                await Task.yield()
                PasserbyHTMLCardView.scheduleShellWarmOnce()
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

/// System Face ID first (lock chrome hidden). After unlock: acknowledgment
/// (first launch / policy bump), then Main. Later opens: Face ID, then Main.
/// Simulator OwnerAppLock starts unlocked so the first SwiftUI frame is this
/// tree, not cream. Device stays locked until Face ID succeeds.
private struct LaunchRoot: View {
    var body: some View {
        OwnerAppLock { ConsentGateView { Main() } }
    }
}

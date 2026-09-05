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
                // Keychain prefetch is `.utility` after first paint so it
                // cannot steal the Face ID sheet's first tick.
                SnapshotSafeCover.activate()
                await Task.yield()
                RedMedHaptics.prepare()
                profile.beginLaunchPrefetch()
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

/// First launch (or policy-version bump): Before you continue with Face ID
/// on that page, then Main after Agree. Later cold starts skip the gate.
/// No cream Face ID lock. Passerby tapper is not in this tree.
private struct LaunchRoot: View {
    var body: some View {
        ConsentGateView { Main() }
    }
}

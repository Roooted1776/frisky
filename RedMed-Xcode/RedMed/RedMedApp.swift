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
                // Profile restore is owner ContentView.task (device-unlocked
                // Keychain). Face ID is the owner RedMed user page / Edit /
                // Save / Erase, not launch.
                SnapshotSafeCover.activate()
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

/// Before you continue (every cold start) then Main after Agree this process.
/// Same session stays in Main. No cream Face ID lock. Passerby tapper is not in this tree.
private struct LaunchRoot: View {
    var body: some View {
        ConsentGateView { Main() }
    }
}

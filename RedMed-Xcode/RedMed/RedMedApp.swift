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
                // Snapshot observers + haptics only. Do not warm WKWebView
                // or read tapper.html here — that raced the first Main frame.
                // Keychain restore is owned by ContentView after a short
                // stagger so Face ID's sheet gets the first tick.
                SnapshotSafeCover.activate()
                await Task.yield()
                RedMedHaptics.prepare()
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
    /// Flat cream matching UILaunchScreen for the SplashBoard → first-layout
    /// gap only. Dropped after two yields with `animation: nil` (no fade).
    /// Do **not** wait for `scenePhase == .active`: cold start and Xcode
    /// Debug Stop→Run begin `.inactive`, and debugger attach can sit there
    /// for seconds — that was a full-screen cream hang over Consent/Main /
    /// Face ID. Rose wash stays deferred in `RedMedPageBackground`.
    @State private var holdLaunchCream = true

    var body: some View {
        ZStack {
            ConsentGateView { Main() }

            if holdLaunchCream {
                Color.redmedBg
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .task {
            guard holdLaunchCream else { return }
            await Task.yield()
            await Task.yield()
            var t = Transaction()
            t.animation = nil
            withTransaction(t) { holdLaunchCream = false }
        }
    }
}

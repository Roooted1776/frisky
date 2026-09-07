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
                // Keychain restore is owned by ContentView (ASAP after one
                // yield — no fixed Face ID stagger on returning opens).
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

/// First launch (or policy-version bump): Before you continue (Agree only),
/// then Face ID once, then Main. Later cold starts skip consent and that
/// post-Agree Face ID. No app-wide cream lock. Passerby tapper is not in
/// this tree.
private struct LaunchRoot: View {
    /// Flat cream matching UILaunchScreen for the SplashBoard → first-layout
    /// gap only. Dropped after **one** MainActor yield with `animation: nil`
    /// — same cadence as `RedMedPageBackground`'s rose wash (also one yield),
    /// so the veil never lifts onto a flat Main frame. One yield is the
    /// minimum that still lets ConsentGate/Main lay out under the veil.
    /// Do **not** wait for `scenePhase == .active`.
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
            var t = Transaction()
            t.animation = nil
            withTransaction(t) { holdLaunchCream = false }
        }
    }
}

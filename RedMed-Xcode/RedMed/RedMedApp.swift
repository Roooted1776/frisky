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
            // Associated Domains (applinks:roooted1776.github.io).
            // Wrist-band proximity must not Safari-hijack an iPhone that already
            // has RedMed. BTR / NFC opens this app instead of Safari.
            // Own band / empty RAM (restore in flight) / bad #d= → foreground
            // only — never present a tap-card sheet (that is still "setting off"
            // the phone). Other person's #d= with a loaded owner profile →
            // in-app tap card (no Keychain write, no SOS).
            // Phones without RedMed still get Safari + band-tap SOS auto-arm.
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                let path = url.path.lowercased()
                guard path == "/tapper" || path.hasPrefix("/tapper/") else { return }
                guard let chip = ProfileNFCCodec.decodeProfile(fromURLString: url.absoluteString) else {
                    return
                }
                // No sheet while Keychain restore is empty / in flight, or when
                // this chip is the owner's own band.
                guard profile.hasData, !profile.matchesBand(chip) else { return }
                NotificationCenter.default.post(
                    name: .redMedOpenBandURL,
                    object: url.absoluteString
                )
            }
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

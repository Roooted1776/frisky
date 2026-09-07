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
                // Snapshot observers only. Keychain prefetch starts here so
                // the blob is in flight during SplashBoard → first frame.
                // Haptics prepare after YOU paints (ContentView) — not here.
                SnapshotSafeCover.activate()
                profile.beginLaunchPrefetch()
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
    /// Returning opens: no SwiftUI cream veil — UILaunchScreen already matches
    /// and ConsentGate goes straight to Main. First launch (or after Erase /
    /// policy bump): flat cream for SplashBoard → Agree layout, dropped after
    /// one yield locked with `RedMedPageBackground`'s wash.
    @State private var holdLaunchCream = !ConsentSettings.hasAcceptedCurrent

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

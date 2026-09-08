import SwiftUI

@main
struct RedMedApp: App {
    @StateObject private var profile = ProfileData()

    init() {
        // Marks process start after dyld / debugger attach.
        // Cream with no ColdLaunch lines yet = Xcode install + LLDB, not SwiftUI.
        RedMedSignpost.coldLaunchMark("app.init")
        // Register switcher-cover observers before the first resign (Debug
        // attach can resign before any SwiftUI .task).
        SnapshotSafeCover.activate()
    }

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
                // Prefetch + MainActor adopt already started from ProfileData.init.
                // Safety net if init skipped the gate path. Haptics stay in
                // ContentView after YOU paints.
                profile.beginLaunchPrefetch()
            }
            .onOpenURL { url in
                let scheme = (url.scheme ?? "").lowercased()
                let host = (url.host ?? "").lowercased()
                if scheme == "redmed", host == "nfc" {
                    NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                    return
                }
                // Safari tapper handoff when Associated Domains / AASA did not
                // claim the tap (stale github.io AASA, personal-team signing).
                // `redmed://band#d=` — same quiet rules as Universal Links.
                if scheme == "redmed", host == "band" || host == "tapper" {
                    handleIncomingBandURL(url.absoluteString, profile: profile)
                }
            }
            // Associated Domains (applinks:roooted1776.github.io).
            // Wrist-band proximity must not Safari-hijack an iPhone that already
            // has RedMed. BTR / NFC opens this app instead of Safari.
            // Own band / empty RAM (restore in flight) / bad #d= → foreground
            // only — never present a tap-card sheet (that is still "setting off"
            // the phone). Other person's `#d=` with a loaded owner profile →
            // in-app tap card (no Keychain write, no SOS).
            // UL often drops the URL fragment — no `#d=` still means quiet
            // (owner phone must not scream). Phones without RedMed keep Safari
            // + band-tap SOS; tapper also tries `redmed://band` before arming.
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                let path = url.path.lowercased()
                guard path == "/tapper" || path.hasPrefix("/tapper/") else { return }
                handleIncomingBandURL(url.absoluteString, profile: profile)
            }
        }
    }
}

/// Own / empty / undecodable `#d=` → foreground only. Foreign chip → in-app card.
private func handleIncomingBandURL(_ urlString: String, profile: ProfileData) {
    guard let chip = ProfileNFCCodec.decodeProfile(fromURLString: urlString) else {
        return
    }
    guard profile.hasSensitiveProfileData, !profile.matchesBand(chip) else { return }
    NotificationCenter.default.post(
        name: .redMedOpenBandURL,
        object: urlString
    )
}

/// First launch (or policy-version bump): Before you continue (Agree only),
/// then Face ID while Main warms, then Main interactive. Later cold starts
/// skip Before You Continue but still Face ID once on cream over warm Main
/// (Keychain restore / prefetch already racing underneath — no fixed sleep).
/// Same-session resume does not re-prompt. No OwnerAppLock relock. Passerby
/// tapper is not in this tree.
private struct LaunchRoot: View {
    /// Returning opens: no SwiftUI cream veil — UILaunchScreen already matches
    /// and ConsentGate paints Face ID cream over armed Main. First launch
    /// (or after Erase / policy bump): flat cream for SplashBoard → Agree
    /// layout, dropped after one yield. Page rose wash is deferred (~400ms)
    /// so it does not fight that drop or a returning Keychain adopt.
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
        .onAppear {
            // Ends coldLaunchWindow at firstFrame (app.init → first paint).
            // Lag *before* app.init (no ColdLaunch lines) is install/attach.
            RedMedSignpost.coldLaunchFirstFrameOnce()
            // Main-ready is ConsentGate after Face ID (returning and fresh).
        }
        .task {
            guard holdLaunchCream else { return }
            await Task.yield()
            var t = Transaction()
            t.animation = nil
            withTransaction(t) { holdLaunchCream = false }
            RedMedSignpost.coldMark("cream dropped")
        }
    }
}

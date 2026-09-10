import SwiftUI

@main
struct RedMedApp: App {
    @StateObject private var profile = ProfileData()
    /// Band / UL ingress — presents the tap card above ConsentGate so Face ID
    /// / Before You Continue never gate tap-to-view.
    @StateObject private var bandTap = BandTapIngress()

    init() {
        // Marks process start after dyld / debugger attach.
        // Cream with no ColdLaunch lines yet = Xcode install + LLDB, not SwiftUI.
        // Multi-second app.init → firstFrame under Debug Run is usually LLDB —
        // A/B with scheme RedMed-NoDebug / Run Without Debugging.
        RedMedSignpost.coldLaunchMark("app.init")
        // Register switcher-cover observers before the first resign (Debug
        // attach can resign before any SwiftUI .task).
        SnapshotSafeCover.activate()
        RedMedSignpost.coldMark("SnapshotSafeCover ready")
    }

    var body: some Scene {
        WindowGroup {
            PrivacySnapshotGuard {
                LaunchRoot()
            }
            .environmentObject(profile)
            .environmentObject(bandTap)
            .background(Color.redmedBg.ignoresSafeArea())
            .background(CreamWindowBackground())
            .preferredColorScheme(.light)
            .task {
                // Returning cold: Prefetch + MainActor adopt already started
                // from ProfileData.init. This is only a safety net if init
                // skipped the gate. Consent-pending must NOT adopt here —
                // that raced cream drop / ack layout (objectWillChange under
                // Before You Continue). Agree calls beginLaunchPrefetch.
                // Haptics stay in ContentView after YOU paints.
                guard ConsentSettings.hasAcceptedCurrent else { return }
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
                    bandTap.ingest(url.absoluteString, profile: profile)
                }
            }
            // Associated Domains (applinks:roooted1776.github.io).
            // Wrist-band proximity must not Safari-hijack an iPhone that already
            // has RedMed. BTR / NFC opens this app instead of Safari.
            // Own matching `#d=` → foreground only (no card sheet).
            // Any other decodable `#d=` → ungated in-app tap card (no Face ID,
            // no Before You Continue, no Keychain write, no SOS). Empty owner
            // funnel and restore-in-flight still show the card once settle says
            // it is not own-match — helpers who installed RedMed must not lose
            // the patient card to a start screen.
            // UL often drops the URL fragment — no `#d=` still means quiet
            // (owner phone must not scream). Phones without RedMed keep Safari
            // + band-tap SOS; tapper also tries `redmed://band` before arming.
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                guard let url = activity.webpageURL else { return }
                let path = url.path.lowercased()
                guard path == "/tapper" || path.hasPrefix("/tapper/") else { return }
                bandTap.ingest(url.absoluteString, profile: profile)
            }
        }
    }
}

/// In-app band / Universal Link tap card. Lives above `ConsentGateView` so
/// tap-to-view never hits Face ID, login, or Before You Continue.
@MainActor
final class BandTapIngress: ObservableObject {
    struct Session: Identifiable, Equatable {
        let id = UUID()
        let urlString: String
    }

    @Published var session: Session?
    /// URL waiting on Keychain restore before own-match vs foreign decision.
    private var queuedURL: String?

    /// True while an ungated band tap card is up — ConsentGate must not Face ID.
    var isPresentingTapCard: Bool { session != nil }

    func ingest(_ urlString: String, profile: ProfileData) {
        guard ProfileNFCCodec.decodeProfile(fromURLString: urlString) != nil else {
            // Bad / missing `#d=` → quiet foreground only.
            return
        }
        // Own-match needs RAM. Queue while Keychain restore is in flight so
        // the wearer's own band does not flash a passerby sheet.
        if profile.isRestoringFromKeychain {
            queuedURL = urlString
            return
        }
        decide(urlString, profile: profile)
    }

    /// Call when Keychain restore settles (`isRestoringFromKeychain` → false).
    func profileRestoreDidSettle(profile: ProfileData) {
        guard let url = queuedURL else { return }
        queuedURL = nil
        decide(url, profile: profile)
    }

    private func decide(_ urlString: String, profile: ProfileData) {
        guard let chip = ProfileNFCCodec.decodeProfile(fromURLString: urlString) else {
            return
        }
        // Own matching band → quiet (wrist proximity must not present the
        // passerby sheet on the wearer's phone).
        if profile.hasSensitiveProfileData, profile.matchesBand(chip) {
            return
        }
        // Foreign chip, or empty owner funnel (helper who installed RedMed) →
        // ungated tap card. No Face ID, no ConsentGate, no Keychain write.
        open(urlString)
    }

    private func open(_ urlString: String) {
        _ = BiometricAuth.cancelInFlight()
        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            session = Session(urlString: urlString)
        }
    }

    func dismiss() {
        var t = Transaction()
        t.animation = nil
        withTransaction(t) {
            session = nil
        }
    }
}

/// First launch (or policy-version bump): Before you continue (Agree only),
/// then Face ID while Main warms, then Main interactive. Later cold starts
/// skip Before You Continue but still Face ID once on cream over warm Main
/// (Keychain restore / prefetch already racing underneath — no fixed sleep).
/// Same-session resume does not re-prompt. No OwnerAppLock relock. Passerby
/// tapper is not in this tree — band / UL tap cards present above the gate.
private struct LaunchRoot: View {
    @EnvironmentObject private var profile: ProfileData
    @EnvironmentObject private var bandTap: BandTapIngress
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
            // Flush a band URL queued during restore if settle already happened.
            if !profile.isRestoringFromKeychain {
                bandTap.profileRestoreDidSettle(profile: profile)
            }
        }
        .task {
            guard holdLaunchCream else { return }
            await Task.yield()
            var t = Transaction()
            t.animation = nil
            withTransaction(t) { holdLaunchCream = false }
            RedMedSignpost.coldMark("cream dropped")
        }
        // Restore settled → flush queued band URL (own-match quiet vs card).
        .onChange(of: profile.isRestoringFromKeychain) { _, restoring in
            if !restoring {
                bandTap.profileRestoreDidSettle(profile: profile)
            }
        }
        // Ungated tap card above ConsentGate / Face ID / Before You Continue.
        .fullScreenCover(item: Binding(
            get: { bandTap.session },
            set: { bandTap.session = $0 }
        )) { session in
            PasserbyHTMLCardView(
                payloadOrURL: session.urlString,
                braceletLinked: false,
                embedProfileJSON: nil
            )
            .environment(\.isScannerSession, true)
            .presentationBackground(Color.redmedBg)
        }
    }
}

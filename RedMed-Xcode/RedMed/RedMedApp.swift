import SwiftUI

@main
struct RedMedApp: App {
    @StateObject private var profile = ProfileData()

    var body: some Scene {
        WindowGroup {
            // Owner UI lives in Main.swift — not HTML.
            // Privacy cover hides PHI from iOS app-switcher snapshots.
            // First open: Face ID on Before you continue, then the ack, then Main.
            // Later opens: Face ID lock, then Main. Consent is first-launch only,
            // never on passerby tapper.
            PrivacySnapshotGuard {
                LaunchRoot()
            }
            // On the guard (not only the lock) so capture cover can see purged vs PHI-in-RAM.
            .environmentObject(profile)
            // Match launch screen so any pre-paint gap stays cream, not system black/white.
            .background(Color.redmedBg.ignoresSafeArea())
            .background(CreamWindowBackground())
            // Main.dc / cream chrome is light-only — keep phone + Xcode/sim identical.
            .preferredColorScheme(.light)
            .task {
                // Registers the willResignActive/didBecomeActive observers before
                // the app can possibly resign active for the first time.
                SnapshotSafeCover.activate()
                try? await Task.sleep(nanoseconds: 300_000_000)
                PasserbyHTMLCardView.scheduleShellWarmOnce()
                // Vault directory create used to run ~1.5s after first paint,
                // which overlapped a slow Face ID / passcode sheet and hit
                // complete-protection file I/O during the Neural Engine window.
                // OwnerAppLock starts it after unlock instead.
            }
            .onOpenURL { url in
                // Policies use redmed://main; owner embed status uses redmed://nfc.
                if (url.scheme ?? "").lowercased() == "redmed",
                   (url.host ?? "").lowercased() == "nfc" {
                    NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                }
            }
            // Associated Domains (applinks:roooted1776.github.io, /tapper/* only) is
            // currently PARKED — personal/free Apple Developer teams cannot provision
            // that capability, so it is out of RedMed.entitlements (see
            // docs/NFC-RESTORE.md for the same personal-team pattern; restore steps
            // below). While parked this handler never fires and a device with RedMed
            // installed opens its own band tap in Safari like any passerby. Once
            // restored: a device with RedMed installed taps its own band → iOS hands
            // the URL here instead of opening it in Safari. There is nothing to
            // render: the owner already has full access through the app itself.
            // Deliberately drop the tapped #d= payload rather than adopt it — this
            // brings the app to the front only, same as tapping the icon. A
            // passerby's phone (no RedMed installed) is unaffected and still opens
            // the hosted tapper card in Safari as normal.
            // Restore (paid Program): add com.apple.developer.associated-domains =
            // [applinks:roooted1776.github.io] back to RedMed.entitlements, then
            // confirm apple-app-site-association is served at the domain root.
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { _ in }
        }
    }
}

/// First process: Face ID on Before you continue, then acknowledgment, then Main.
/// Same session stays on this tree after Agree so we do not remount OwnerAppLock
/// and Face ID again. Next cold start uses the lock (consent already accepted).
private struct LaunchRoot: View {
    @State private var needsConsent = !ConsentSettings.hasAcceptedCurrent

    var body: some View {
        Group {
            if needsConsent {
                ConsentGateView { Main() }
            } else {
                OwnerAppLock { Main() }
            }
        }
        .onAppear {
            guard needsConsent else { return }
            // Do not leave the switcher cream veil over the first page.
            OwnerLockPresentation.setLocked(false)
            SnapshotSafeCover.shared.reveal()
        }
    }
}

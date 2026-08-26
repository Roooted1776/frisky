import SwiftUI

@main
struct RedMedApp: App {
    @StateObject private var profile = ProfileData()

    var body: some Scene {
        WindowGroup {
            // Owner UI lives in Main.swift — not HTML.
            // Privacy cover hides PHI from iOS app-switcher snapshots.
            // Face ID first (no extra pages before the lock). Consent is
            // first-launch only, after unlock, never on passerby tapper.
            PrivacySnapshotGuard {
                OwnerAppLock {
                    ConsentGateView {
                        Main()
                    }
                }
            }
            // On the guard (not only the lock) so capture cover can see purged vs PHI-in-RAM.
            .environmentObject(profile)
            // Match launch screen so any pre-paint gap stays cream, not system black/white.
            .background(Color.redmedBg.ignoresSafeArea())
            .background(CreamWindowBackground())
            // Main.dc / cream chrome is light-only — keep phone + Xcode/sim identical.
            .preferredColorScheme(.light)
            .task {
                // Shell string during Face ID window. Vault I/O waits — do not fight SecItem/LA.
                // CoreMotion still starts after unlock (OwnerAppLock). .utility so this
                // does not compete with the Face ID sheet for CPU on cold launch.
                Task.detached(priority: .utility) {
                    PasserbyHTMLCardView.warmShellCache()
                }
                Task.detached(priority: .utility) {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    _ = HIPAAOfflineVault.prepare()
                }
            }
            .onOpenURL { url in
                // Policies use redmed://main; owner embed status uses redmed://nfc.
                if (url.scheme ?? "").lowercased() == "redmed",
                   (url.host ?? "").lowercased() == "nfc" {
                    NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                }
            }
            // Associated Domains (applinks:roooted1776.github.io, /tapper/* only —
            // see RedMed.entitlements). A device with RedMed installed taps its own
            // band → iOS hands the URL here instead of opening it in Safari. There is
            // nothing to render: the owner already has full access through the app
            // itself. Deliberately drop the tapped #d= payload rather than adopt it —
            // this brings the app to the front only, same as tapping the icon. A
            // passerby's phone (no RedMed installed) is unaffected and still opens
            // the hosted tapper card in Safari as normal.
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { _ in }
        }
    }
}

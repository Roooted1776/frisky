import SwiftUI

@main
struct RedMedApp: App {
    @StateObject private var profile = ProfileData()

    var body: some Scene {
        WindowGroup {
            // Owner UI lives in Main.swift — not HTML.
            // Privacy cover hides PHI from iOS app-switcher snapshots.
            PrivacySnapshotGuard {
                OwnerAppLock {
                    Main()
                }
            }
            // On the guard (not only the lock) so capture cover can see purged vs PHI-in-RAM.
            .environmentObject(profile)
            // Match launch screen so any pre-paint gap stays cream, not system black.
            .background(Color.redmedBg.ignoresSafeArea())
            // Main.dc / cream chrome is light-only — keep phone + Xcode/sim identical.
            .preferredColorScheme(.light)
            .task {
                // Vault + tapper.html string only — WKWebView warm starts after unlock paint.
                // CoreMotion still starts after unlock (OwnerAppLock).
                Task.detached(priority: .utility) {
                    _ = HIPAAOfflineVault.prepare()
                    PasserbyHTMLCardView.warmShellCache()
                }
            }
            .onOpenURL { url in
                // Policies use redmed://main; owner embed status uses redmed://nfc.
                if (url.scheme ?? "").lowercased() == "redmed",
                   (url.host ?? "").lowercased() == "nfc" {
                    NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                }
            }
        }
    }
}

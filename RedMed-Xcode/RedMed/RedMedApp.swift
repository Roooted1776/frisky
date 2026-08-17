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
            // Match launch screen so any pre-paint gap stays cream, not system black/white.
            .background(Color.redmedBg.ignoresSafeArea())
            .background(CreamWindowBackground())
            // Main.dc / cream chrome is light-only — keep phone + Xcode/sim identical.
            .preferredColorScheme(.light)
            .task {
                // Shell string during Face ID window. Vault I/O waits — do not fight SecItem/LA.
                // CoreMotion still starts after unlock (OwnerAppLock).
                Task.detached(priority: .userInitiated) {
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
        }
    }
}

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
                .environmentObject(profile)
            }
            // Match launch screen so any pre-paint gap stays cream, not system black.
            .background(Color.redmedBg.ignoresSafeArea())
            .task {
                // First paint with zero Location / vault / Keychain decode.
                await Task.yield()
                CrashMotionGuard.shared.startMonitoring()
                Task.detached(priority: .utility) {
                    _ = HIPAAOfflineVault.prepare()
                }
            }
            .onOpenURL { url in
                // Policies / get.html redirect with redmed://main
                _ = url
            }
        }
    }
}

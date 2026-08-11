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
            .task {
                // First paint with zero Location; CoreMotion starts after yield.
                await Task.yield()
                CrashMotionGuard.shared.startMonitoring()
            }
            .onAppear {
                HIPAAOfflineVault.prepare()
            }
            .onOpenURL { url in
                // Policies / get.html redirect with redmed://main
                _ = url
            }
        }
    }
}

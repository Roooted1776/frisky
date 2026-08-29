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
                SnapshotSafeCover.activate()
                await Task.yield()
                PasserbyHTMLCardView.scheduleShellWarmOnce()
            }
            .onOpenURL { url in
                if (url.scheme ?? "").lowercased() == "redmed",
                   (url.host ?? "").lowercased() == "nfc" {
                    NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                }
            }
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { _ in }
        }
    }
}

/// First open: Before you continue (no lock cream). Agree opens Main.
/// Later opens: Face ID lock, then Main.
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
            OwnerLockPresentation.setLocked(false)
            SnapshotSafeCover.shared.reveal()
        }
    }
}

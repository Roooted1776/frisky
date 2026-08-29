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
                try? await Task.sleep(nanoseconds: 300_000_000)
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

/// First process: Face ID on Before you continue, then acknowledgment, then Main.
/// Same session stays on this tree after Agree so we do not remount OwnerAppLock.
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

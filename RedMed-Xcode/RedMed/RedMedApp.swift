import SwiftUI

@main
struct RedMedApp: App {
    @ObservedObject private var locationGate = LocationAccessSuggester.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if locationGate.canOpenApp {
                    // Profile/Keychain only after the launch gate — first install
                    // never pays Keychain while Location is still undecided.
                    MainAppRoot()
                } else {
                    // Ask Location before the main tabs open. No GPS updates here.
                    LocationLaunchGateView()
                }
            }
        }
    }
}

/// Owns the Keychain-backed profile. Mounted only once Location has been asked.
private struct MainAppRoot: View {
    @StateObject private var profile = ProfileData()

    var body: some View {
        ContentView()
            .environmentObject(profile)
    }
}

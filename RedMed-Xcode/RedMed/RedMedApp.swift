import SwiftUI

@main
struct RedMedApp: App {
    @StateObject private var profile = ProfileData()
    @ObservedObject private var locationGate = LocationAccessSuggester.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if locationGate.canOpenApp {
                    ContentView()
                        .environmentObject(profile)
                } else {
                    // Ask Location before the main tabs open. No GPS updates here.
                    LocationLaunchGateView()
                }
            }
        }
    }
}

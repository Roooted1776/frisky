import SwiftUI

@main
struct RedMedApp: App {
    @StateObject private var profile = ProfileData()

    var body: some Scene {
        WindowGroup {
            // Owner app opens immediately — edit profile, Aid treatments, NFC write.
            // Do not gate first launch on Location; Find Help asks When-In-Use only
            // when that tab is visible (see EmergencyView / LocationManager).
            ContentView()
                .environmentObject(profile)
        }
    }
}

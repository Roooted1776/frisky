import SwiftUI

@main
struct RedMedApp: App {
    @StateObject private var profile = ProfileData()
    /// Lives for the app lifetime so NFC write/read survives leaving the NFC tab.
    @StateObject private var nfc = NFCManager()
    /// Starts GPS at launch so Find 911 has coordinates without waiting on the tab.
    @StateObject private var emergencyLocation = EmergencyLocationService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(profile)
                .environmentObject(nfc)
                .environmentObject(emergencyLocation)
        }
    }
}

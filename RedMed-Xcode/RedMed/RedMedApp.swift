import SwiftUI

@main
struct RedMedApp: App {
    @StateObject private var profile = ProfileData()
    /// Lives for the app lifetime so NFC write/read survives leaving the NFC tab.
    @StateObject private var nfc = NFCManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(profile)
                .environmentObject(nfc)
        }
    }
}

import SwiftUI

@main
struct RedMedApp: App {
    @StateObject private var profile = ProfileData()

    var body: some Scene {
        WindowGroup {
            // Owner UI lives in Main.swift — not HTML.
            Main()
                .environmentObject(profile)
                .onOpenURL { url in
                    // Policies / card.html redirect with redmed://main
                    _ = url
                }
        }
    }
}

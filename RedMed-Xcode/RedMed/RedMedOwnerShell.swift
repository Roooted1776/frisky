import SwiftUI

enum RedMedOwnerTab: Hashable {
    case profile
    case tag
    case help
}

struct RedMedOwnerShell: View {
    @State private var selectedTab: RedMedOwnerTab = .profile

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                RedMedView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
            .tag(RedMedOwnerTab.profile)
            .accessibilityLabel("Profile")

            NavigationStack {
                NFCView()
            }
            .tabItem {
                Label("Tag", systemImage: "tag")
            }
            .tag(RedMedOwnerTab.tag)
            .accessibilityLabel("RedMed Tag")

            NavigationStack {
                HelpMenuView()
            }
            .tabItem {
                Label("Help", systemImage: "questionmark.circle")
            }
            .tag(RedMedOwnerTab.help)
            .accessibilityLabel("Help and settings")
        }
        .tint(.red)
    }
}

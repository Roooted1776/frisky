import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var store = ProfileStore()
    @StateObject private var braceletLink = BraceletLinkStore()
    /// My ID first — lighter than Find 911 (no GPS / trauma JSON / path monitor on cold start).
    @State private var selectedTab: OwnerTab = .myID
    @Environment(\.scenePhase) private var scenePhase

    /// Tab bar chrome once per process — not on every view rebuild.
    private static let configureTabBar: Void = {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 1, green: 1, blue: 1, alpha: 1)
        appearance.shadowColor = UIColor(red: 0.91, green: 0.92, blue: 0.93, alpha: 1)
        appearance.shadowImage = nil
        let item = UITabBarItemAppearance()
        let muted = UIColor(red: 0.373, green: 0.388, blue: 0.408, alpha: 1)
        item.normal.iconColor = muted
        item.normal.titleTextAttributes = [
            .foregroundColor: muted,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        item.selected.iconColor = UIColor(red: 0.882, green: 0.114, blue: 0.282, alpha: 1)
        item.selected.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.882, green: 0.114, blue: 0.282, alpha: 1),
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]
        item.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -1)
        item.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: -1)
        appearance.stackedLayoutAppearance = item
        appearance.inlineLayoutAppearance = item
        appearance.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        if #available(iOS 26.0, *) {
            UITabBar.appearance().isHidden = false
        }
    }()

    init() {
        _ = Self.configureTabBar
    }

    var body: some View {
        // Switch (not TabView): only the selected tab's StateObjects exist —
        // LocationManager / NWPathMonitor / trauma JSON stay off the cold path.
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .myID:
                    MyIDView()
                case .find911:
                    LocationView()
                case .aid:
                    BasicAidView()
                case .nfc:
                    WriteTagView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 64)

            CustomTabBar(tab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .environmentObject(store)
        .environmentObject(braceletLink)
        .tint(AppTheme.accent)
        .preferredColorScheme(.light)
        .onReceive(NotificationCenter.default.publisher(for: .redMedOpenOwnerTab)) { note in
            guard let raw = note.object as? String else { return }
            switch raw {
            case "911": selectedTab = .find911
            case "aid": selectedTab = .aid
            case "nfc": selectedTab = .nfc
            default: selectedTab = .myID
            }
        }
        .withLayoutMetrics()
        .onAppear {
            braceletLink.promotePostPairingGraceIfEligible()
        }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .active: braceletLink.promotePostPairingGraceIfEligible()
            case .background: braceletLink.noteAppDidBackground()
            default: break
            }
        }
    }
}

#Preview {
    ContentView()
}

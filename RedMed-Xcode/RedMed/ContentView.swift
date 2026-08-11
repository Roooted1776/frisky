import SwiftUI

struct ContentView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .redmed

    /// Ped/EMS scanners: never NFC. Owners see the NFC tab only when hardware is enabled
    /// (`AppConfig.nfcHardwareEnabled`).
    private var showsNFC: Bool { !isScannerSession && AppConfig.nfcHardwareEnabled }

    private var scannerSafeTab: Binding<AppTab> {
        Binding(
            get: {
                if !showsNFC && tab == .nfc { return .redmed }
                return tab
            },
            set: { newValue in
                if !showsNFC && newValue == .nfc {
                    tab = .redmed
                } else {
                    tab = newValue
                }
            }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isScannerSession {
                LocationSuggestionBanner()
            }
            ZStack(alignment: .bottom) {
                Group {
                    switch scannerSafeTab.wrappedValue {
                    case .redmed:
                        RedMedView(tab: scannerSafeTab)
                    case .emergency:
                        EmergencyView()
                    case .aid:
                        AidView()
                    case .nfc:
                        // Scanners never reach here. Owners go straight to NFC write.
                        NFCView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 64)

                CustomTabBar(tab: scannerSafeTab, showsNFC: showsNFC)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        // Location was already asked at the launch gate. Re-check on
        // foreground for denied → Settings; still do not start GPS here.
        .onChange(of: scenePhase) { _, phase in
            guard !isScannerSession, phase == .active else { return }
            LocationAccessSuggester.shared.suggestIfNeeded()
        }
        .onAppear { clampScannerTab() }
        .onChange(of: isScannerSession) { _, _ in clampScannerTab() }
    }

    private func clampScannerTab() {
        if !showsNFC && tab == .nfc {
            tab = .redmed
        }
    }
}

struct CustomTabBar: View {
    @Binding var tab: AppTab
    var showsNFC: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color(red: 0.9, green: 0.9, blue: 0.9))
            HStack(spacing: -3) {
                TabBarItem(icon: "person.fill",  label: "RedMed", isOn: tab == .redmed)      { tab = .redmed }
                TabBarItem(icon: "phone.fill",   label: "Help",   isOn: tab == .emergency)  { tab = .emergency }
                TabBarItem(icon: "cross.case.fill", label: "Aid", isOn: tab == .aid)        { tab = .aid }
                if showsNFC {
                    TabBarItem(icon: "wave.3.right", label: "NFC", isOn: tab == .nfc)        { tab = .nfc }
                }
            }
            .padding(.top, 2)

            Capsule()
                .fill(Color(red: 0.11, green: 0.098, blue: 0.086).opacity(0.18))
                .frame(width: 134, height: 5)
                .padding(.top, 2)
                .padding(.bottom, 4)
        }
        .background(Color.white)
    }
}

struct TabBarItem: View {
    let icon: String
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isOn ? .redmedAccent : Color(red: 0.372, green: 0.388, blue: 0.408))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isOn ? Color.redmedAccent.opacity(0.10) : Color.clear)
                    )
                Text(label)
                    .font(.system(size: 10, weight: isOn ? .semibold : .medium))
                    .foregroundColor(isOn ? .redmedAccent : Color(red: 0.372, green: 0.388, blue: 0.408))
                    .kerning(-0.1)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 3)
        }
        .buttonStyle(.plain)
    }
}

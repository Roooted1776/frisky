import SwiftUI

struct ContentView: View {
    @EnvironmentObject var profile: ProfileData
    @EnvironmentObject var nfc: NFCManager
    @State private var tab: AppTab = .myid

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch tab {
                case .myid:      MyIDView(tab: $tab)
                case .emergency: EmergencyView()
                case .aid:       AidView()
                case .nfc:       NFCView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 64)

            CustomTabBar(tab: $tab)
        }
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: profile.pendingBraceletWrite) { pending in
            if pending { tab = .nfc }
        }
        // Persist pairing even if the user left the NFC tab before write finished.
        .onChange(of: nfc.lastWriteSucceeded) { ok in
            guard ok else { return }
            profile.braceletLinked = true
            profile.persist()
        }
    }
}

struct CustomTabBar: View {
    @Binding var tab: AppTab

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color(red: 0.9, green: 0.9, blue: 0.9))
            HStack(spacing: 0) {
                TabBarItem(icon: "person.fill",  label: "RedMed", isOn: tab == .myid)      { tab = .myid }
                TabBarItem(icon: "phone.fill",   label: "911",    isOn: tab == .emergency)  { tab = .emergency }
                TabBarItem(icon: "cross.case.fill", label: "Aid", isOn: tab == .aid)        { tab = .aid }
                TabBarItem(icon: "wave.3.right", label: "NFC",    isOn: tab == .nfc)        { tab = .nfc }
            }
            .padding(.top, 4)

            Capsule()
                .fill(Color(red: 0.11, green: 0.098, blue: 0.086).opacity(0.18))
                .frame(width: 134, height: 5)
                .padding(.top, 4)
                .padding(.bottom, 8)
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
                    .padding(.vertical, 5)
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
            .padding(.bottom, 6)
        }
        .buttonStyle(.plain)
    }
}

import SwiftUI

/// Root tab shell.
///
/// Permanent product rule:
/// - Owner (`isScannerSession == false`): RedMed · 911 · Aid · NFC (+ Edit on RedMed)
/// - Scanner (`isScannerSession == true`): RedMed · 911 · Aid only (no Edit, no NFC)
///
/// Never gate the NFC tab on `AppConfig.nfcHardwareEnabled` — that flag only
/// disables CoreNFC sessions inside `NFCBandManager` (`NFCWriter` / `NFCReader`).
struct ContentView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    @State private var tab: AppTab = .redmed
    /// Only mount a tab's heavy subtree after first visit; keep it alive after.
    @State private var mountedTabs: Set<AppTab> = [.redmed]

    /// Owner-only fourth tab. Scanners never see NFC.
    private var showsNFC: Bool { !isScannerSession }

    private var activeTab: AppTab { scannerSafeTab.wrappedValue }

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
        // No Location banner / CLLocationManager here — Find Help owns that.
        ZStack(alignment: .bottom) {
            ZStack {
                mountedTab(.redmed) { RedMedView(tab: scannerSafeTab) }
                mountedTab(.emergency) { EmergencyView() }
                mountedTab(.aid) { AidView() }
                if showsNFC {
                    mountedTab(.nfc) { NFCView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 64)

            CustomTabBar(tab: scannerSafeTab, showsNFC: showsNFC)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            mountedTabs.insert(activeTab)
            clampScannerTab()
        }
        .onChange(of: tab) { _, newTab in
            mountedTabs.insert(newTab)
        }
        .onChange(of: isScannerSession) { _, _ in clampScannerTab() }
    }

    @ViewBuilder
    private func mountedTab<Content: View>(
        _ tab: AppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if mountedTabs.contains(tab) {
            content()
                .opacity(activeTab == tab ? 1 : 0)
                .allowsHitTesting(activeTab == tab)
                .accessibilityHidden(activeTab != tab)
        }
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
                TabBarItem(icon: "phone.fill",   label: "911",    isOn: tab == .emergency)  { tab = .emergency }
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

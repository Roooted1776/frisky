import SwiftUI

/// Root tab shell.
///
/// Permanent product rule (bracelet tap / scanner):
/// - Owner (`isScannerSession == false`): RedMed · 911 · Aid · NFC (+ Edit on RedMed).
///   Help chrome on every native screen except the Face ID lock shell.
/// - Scanner / tap (`isScannerSession == true` or HTML `tapper.html#d=`): RedMed · 911 · Aid
///   only — **no Edit**, **no NFC**. Help is policies-only (no Settings / Erase / NFC write).
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
            // Same cream as tapper body / RedMedPageBackground — no system white in tab gaps.
            Color.redmedBg.ignoresSafeArea()
                .allowsHitTesting(false)

            ZStack {
                mountedTab(.redmed) { RedMedView() }
                mountedTab(.emergency) {
                    EmergencyView(isVisible: activeTab == .emergency)
                }
                mountedTab(.aid) { AidView() }
                if showsNFC {
                    mountedTab(.nfc) { NFCView() }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 56)

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
        // Crash / SOS → 911. Notification avoids @ObservedObject on the root tab tree
        // (that rebuilt RedMed's WKWebView on every arm/disarm).
        .onReceive(NotificationCenter.default.publisher(for: .redMedSurvivalArmed)) { _ in
            tab = .emergency
            mountedTabs.insert(.emergency)
        }
        // Owner RedMed status (Not linked / Linked bracelet) → NFC Write / Scan.
        .onReceive(NotificationCenter.default.publisher(for: .redMedOpenNFCTab)) { _ in
            guard showsNFC else { return }
            tab = .nfc
            mountedTabs.insert(.nfc)
        }
        .presentsOwnerHelp()
    }

    @ViewBuilder
    private func mountedTab<Content: View>(
        _ tab: AppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if mountedTabs.contains(tab) {
            content()
                .opacity(activeTab == tab ? 1 : 0)
                // Discrete swap — spring/fade on a live WKWebView is visible jank.
                .transaction { $0.animation = nil }
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

    /// Continuous rounded top — polished bottom chrome without frost (opaque cream).
    private var barShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: 18,
            style: .continuous
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                TabBarItem(icon: "person.fill",  label: "RedMed", isOn: tab == .redmed) {
                    select(.redmed)
                }
                TabBarItem(icon: "safari.fill",  label: "911",    isOn: tab == .emergency) {
                    select(.emergency)
                }
                TabBarItem(icon: "cross.case.fill", label: "Aid", isOn: tab == .aid) {
                    select(.aid)
                }
                if showsNFC {
                    TabBarItem(icon: "wave.3.right", label: "NFC", isOn: tab == .nfc) {
                        select(.nfc)
                    }
                }
            }
            .padding(.top, 4.5)

            Capsule()
                .fill(Color.redmedDark.opacity(0.18))
                .frame(width: 118, height: 4)
                .padding(.top, 2)
                .padding(.bottom, 3)
        }
        .background {
            barShape
                .fill(Color.redmedBg)
                .overlay {
                    barShape.strokeBorder(Color.redmedDivider, lineWidth: 0.5)
                }
                .shadow(color: Color.black.opacity(0.05), radius: 10, y: -2)
                .allowsHitTesting(false)
        }
        // Bar bounds only — upward shadow must not eat YOU-card / list taps.
        .contentShape(barShape)
    }

    private func select(_ next: AppTab) {
        guard tab != next else {
            RedMedHaptics.selection()
            return
        }
        RedMedHaptics.selection()
        // No withAnimation on AppTab — that marks the content ZStack transaction even
        // when mounted tabs suppress animation, and fights opacity keep-alive.
        tab = next
    }
}

struct TabBarItem: View {
    let icon: String
    let label: String
    let isOn: Bool
    let action: () -> Void

    /// 911 uses `safari.fill` — hierarchical keeps the compass needle visible
    /// (flat monochrome fills the disc solid, same failure as tapper without evenodd).
    private var tint: Color {
        isOn ? .redmedAccent : Color(red: 0.372, green: 0.388, blue: 0.408)
    }

    private var isCompass: Bool { icon == "safari.fill" }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isOn ? .semibold : .regular))
                    .symbolRenderingMode(isCompass ? .hierarchical : .monochrome)
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: 11)
                            .fill(isOn ? Color.redmedAccent.opacity(0.12) : Color.clear)
                    )
                Text(label)
                    .font(.system(size: 10, weight: isOn ? .semibold : .medium))
                    .foregroundColor(tint)
                    .kerning(-0.1)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            // Discrete tint swap — no spring/bounce on every tab hop.
            .transaction { $0.animation = nil }
        }
        .buttonStyle(RedMedPressStyle(scale: 0.96, haptic: nil))
    }
}

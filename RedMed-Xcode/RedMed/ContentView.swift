import SwiftUI

/// Root tab shell.
///
/// Permanent product rule (bracelet tap / scanner):
/// - Owner (`isScannerSession == false`): RedMed · 911 · Aid · NFC (+ Edit on RedMed).
///   Help chrome on every native screen except the Edit modal.
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
                // Mount in the same turn as `tab` — `onChange` ran *after* the
                // first body pass, so 911 / Aid / NFC painted empty cream on
                // first tap (the unreliable load).
                let next: AppTab = (!showsNFC && newValue == .nfc) ? .redmed : newValue
                mountedTabs.insert(next)
                tab = next
            }
        )
    }

    var body: some View {
        // No Location banner / CLLocationManager here — Find Help owns that.
        ZStack(alignment: .bottom) {
            // Same cream as tapper body / RedMedPageBackground — no system white in tab gaps.
            Color.redmedBg.ignoresSafeArea()
                .allowsHitTesting(false)

            // Keep-alive stack at origin. Inactive tabs hide at opacity 0.
            // RedMed is a native YOU card — no WKWebView to park at 0.02.
            ZStack {
                mountedTab(.redmed, epoch: profile.cardEpoch) {
                    RedMedView()
                }
                mountedTab(.emergency) {
                    EmergencyView(isVisible: activeTab == .emergency)
                }
                mountedTab(.aid) { AidView() }
                if showsNFC {
                    mountedTab(.nfc) {
                        NFCView(isVisible: activeTab == .nfc)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, RedMedChrome.tabBarHeight)

            CustomTabBar(tab: scannerSafeTab, showsNFC: showsNFC)
        }
        .ignoresSafeArea(edges: .bottom)
        .task {
            guard !isScannerSession else { return }
            await profile.restoreOnLaunch()
        }
        .onAppear {
            mountedTabs.insert(activeTab)
            clampScannerTab()
            RedMedHaptics.prepare()
            // Same-turn mount in scannerSafeTab already paints 911 / Aid / NFC
            // on first tap. Do not pre-stack those pages under RedMed — that
            // kept GPS / Aid catalog / NFC WK warm compositing for the session.
            if !isScannerSession {
                Task { @MainActor in
                    await Task.yield()
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    guard !Task.isCancelled else { return }
                    CrashMotionGuard.shared.startMonitoring()
                }
            }
        }
        .onChange(of: tab) { _, newTab in
            mountedTabs.insert(newTab)
        }
        .onChange(of: isScannerSession) { _, _ in clampScannerTab() }
        // Crash / SOS → 911. Notification avoids @ObservedObject on the root tab tree.
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
        parksWebView: Bool = false,
        epoch: UInt = 0,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if mountedTabs.contains(tab) {
            IsolatedKeepAliveTab(
                isFront: activeTab == tab,
                parksWebView: parksWebView,
                epoch: epoch,
                content: content()
            )
            .equatable()
        }
    }

    private func clampScannerTab() {
        if !showsNFC && tab == .nfc {
            tab = .redmed
        }
    }
}

/// Parks a mounted tab without tearing it down. Front tab re-diffs when
/// `epoch` changes (Keychain restore / save) or when it becomes front.
/// A tab that stayed in back skips `body` so 911 GPS / Aid accordion / NFC
/// pack do not rebuild on every hop. All owner tabs are native (Preview
/// WKWebView is a full-screen cover), so back tabs hide at opacity 0.
private struct IsolatedKeepAliveTab<Content: View>: View, Equatable {
    let isFront: Bool
    let parksWebView: Bool
    let epoch: UInt
    let content: Content

    static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.parksWebView == rhs.parksWebView else { return false }
        guard lhs.epoch == rhs.epoch else { return false }
        if lhs.isFront != rhs.isFront { return false }
        return !lhs.isFront
    }

    var body: some View {
        content
            .opacity(displayOpacity)
            .zIndex(isFront ? 1 : 0)
            .transaction { $0.animation = nil }
            .allowsHitTesting(isFront)
            .accessibilityHidden(!isFront)
    }

    private var displayOpacity: Double {
        if isFront { return 1 }
        // 0 blanks WKCompositingView. Native pages have no web view.
        return parksWebView ? 0.02 : 0
    }
}

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

struct CustomTabBar: View {
    @Binding var tab: AppTab
    var showsNFC: Bool = true

    /// Continuous rounded top — polished bottom chrome without frost (opaque cream).
    private var barShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: RedMedChrome.tabTopRadius,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: RedMedChrome.tabTopRadius,
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
                .accessibilityHidden(true)
        }
        .background {
            barShape
                .fill(Color.redmedBg)
                .overlay {
                    barShape.strokeBorder(Color.redmedDivider, lineWidth: 0.5)
                }
                .shadow(color: RedMedChrome.cardShadow, radius: 10, y: -2)
                // This bar is on-screen behind every tab's scroll content —
                // flatten its static fill/stroke/shadow to one GPU texture so
                // scrolling underneath doesn't force a CPU shadow recompute
                // on every frame.
                .drawingGroup()
                .allowsHitTesting(false)
        }
        // Bar bounds only — upward shadow must not eat YOU-card / list taps.
        .contentShape(barShape)
        .accessibilityElement(children: .contain)
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
        isOn ? .redmedAccent : .redmedMuted
    }

    private var isCompass: Bool { icon == "safari.fill" }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isOn ? .semibold : .regular))
                    .symbolRenderingMode(isCompass ? .hierarchical : .monochrome)
                    .foregroundStyle(tint)
                    // Square W×H so each SF Symbol's glyph center matches the slot center.
                    .frame(width: 26, height: 26, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: RedMedChrome.chipRadius, style: .continuous)
                            .fill(isOn ? Color.redmedAccent.opacity(0.12) : Color.clear)
                    )
                    .accessibilityHidden(true)
                Text(label)
                    .font(.system(size: 10, weight: isOn ? .semibold : .medium))
                    .foregroundColor(tint)
                    .kerning(-0.1)
                    // Shrink-to-fit instead of a manual GeometryReader size calc —
                    // keeps "RedMed" from clipping/overflowing its slot without
                    // reintroducing the layout complexity 5ada426 added.
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(minHeight: 44)
            // Discrete tint swap — no spring/bounce on every tab hop.
            .transaction { $0.animation = nil }
        }
        // Instant press — the 0.32s CTA spring made hops feel late.
        .buttonStyle(RedMedPressStyle(scale: 0.98, haptic: nil, animates: false))
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isOn ? "Selected" : "Switch to \(label)")
    }
}

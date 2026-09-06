import SwiftUI

/// Root tab shell.
///
/// Permanent product rule (bracelet tap / scanner):
/// - Owner (`isScannerSession == false`): RedMed · 911 · Aid · NFC (+ Edit chrome on RedMed, not on the YOU-card / Preview header).
///   Help chrome on every native screen except the Edit modal.
/// - Scanner / tap (`isScannerSession == true` or HTML `tapper.html#d=`): RedMed · 911 · Aid
///   only — **no Edit**, **no NFC**. Help is policies-only (no Settings / Erase / NFC write).
///
/// Never gate the NFC tab on `AppConfig.nfcHardwareEnabled` — that flag only
/// disables CoreNFC sessions inside `NFCBandManager` (`NFCWriter` / `NFCReader`).
struct ContentView: View {
    @EnvironmentObject var profile: ProfileData
    @Environment(\.isScannerSession) private var isScannerSession
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .redmed
    /// Only mount a tab's heavy subtree after first visit; keep it alive after.
    @State private var mountedTabs: Set<AppTab> = [.redmed]
    /// Owned here so the NFC tab tap can begin CoreNFC on the same gesture stack.
    @StateObject private var nfcBand = NFCBandManager()

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
            // One wash for every tab. Per-tab RedMedPageBackground stacked four
            // RadialGradients under opacity-0 keep-alive pages and made hops hitch.
            RedMedPageBackground()

            // Keep-alive stack at origin. Inactive tabs hide at opacity 0.
            // RedMed is a native YOU card — no WKWebView to park at 0.02.
            ZStack {
                mountedTab(.redmed, epoch: profile.cardEpoch) {
                    RedMedView(isVisible: activeTab == .redmed)
                }
                mountedTab(.emergency, refreshOnHide: true) {
                    EmergencyView(isVisible: activeTab == .emergency)
                }
                mountedTab(.aid) { AidView() }
                if showsNFC {
                    mountedTab(.nfc, refreshOnHide: true) {
                        NFCView(isVisible: activeTab == .nfc, band: nfcBand)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, RedMedChrome.tabBarHeight)

            CustomTabBar(tab: scannerSafeTab, showsNFC: showsNFC, onNFCWrite: {
                startHoldToWriteFromNFCTab()
            })
        }
        .ignoresSafeArea(edges: .bottom)
        .task {
            guard !isScannerSession else { return }
            // Stagger past Face ID sheet presentation (returning RedMed
            // unlock or first-launch ConsentGate). Starting SecItem in the
            // same turn as evaluatePolicy contended for the sheet's first
            // tick — see docs/cold-start-audit.md. Prefetch still overlaps
            // the Face ID interaction; it just does not lead it.
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await profile.restoreOnLaunch()
        }
        .onAppear {
            mountedTabs.insert(activeTab)
            clampScannerTab()
            // Same-turn mount in scannerSafeTab already paints 911 / Aid / NFC
            // on first tap. Do not pre-stack those pages under RedMed — that
            // kept GPS / Aid catalog / NFC WK warm compositing for the session.
            // First paint first — haptics / CoreMotion after the YOU card yields.
            Task { @MainActor in
                await Task.yield()
                RedMedHaptics.prepare()
                try? await Task.sleep(nanoseconds: 400_000_000)
                guard !Task.isCancelled else { return }
                guard scenePhase == .active else { return }
                startCrashMonitorIfOwner()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard !isScannerSession else { return }
            switch phase {
            case .active:
                startCrashMonitorIfOwner()
            case .background:
                // No motion background mode — CoreMotion is useless when
                // suspended. Stop the session so the next `.active` can
                // start a fresh one. Does not cancel an armed siren.
                CrashMotionGuard.shared.stopMonitoring()
            default:
                // `.inactive` is Face ID on the RedMed user page / Edit /
                // Save / Erase, Control Center, app switcher peek. Keep
                // listening.
                break
            }
        }
        .onChange(of: tab) { _, newTab in
            mountedTabs.insert(newTab)
            if newTab != .nfc {
                nfcBand.cancelSessions()
            }
        }
        .onChange(of: isScannerSession) { _, _ in clampScannerTab() }
        // Crash / SOS → 911. Notification avoids @ObservedObject on the root tab tree.
        .onReceive(NotificationCenter.default.publisher(for: .redMedSurvivalArmed)) { _ in
            tab = .emergency
            mountedTabs.insert(.emergency)
        }
        // Owner RedMed status (Not linked / Linked bracelet) → NFC Write.
        .onReceive(NotificationCenter.default.publisher(for: .redMedOpenNFCTab)) { _ in
            guard showsNFC else { return }
            tab = .nfc
            mountedTabs.insert(.nfc)
            startHoldToWriteFromNFCTab()
        }
        .presentsOwnerHelp()
    }

    /// Open the CoreNFC write sheet on the NFC-tab / Write CTA stack.
    /// Hold the band ~1–2″ finishes the program — iOS has no silent write.
    private func startHoldToWriteFromNFCTab() {
        guard showsNFC, !isScannerSession else { return }
        guard AppConfig.nfcHardwareEnabled else { return }
        guard profile.hasData else { return }
        nfcBand.writeBand(from: profile, isScannerSession: false)
    }

    @ViewBuilder
    private func mountedTab<Content: View>(
        _ tab: AppTab,
        parksWebView: Bool = false,
        epoch: UInt = 0,
        refreshOnHide: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if mountedTabs.contains(tab) {
            IsolatedKeepAliveTab(
                isFront: activeTab == tab,
                parksWebView: parksWebView,
                epoch: epoch,
                refreshOnHide: refreshOnHide,
                content: content()
            )
        }
    }

    private func clampScannerTab() {
        if !showsNFC && tab == .nfc {
            tab = .redmed
        }
    }

    /// Owner Main only. Scanner / passerby never start CoreMotion.
    private func startCrashMonitorIfOwner() {
        guard !isScannerSession else { return }
        CrashMotionGuard.shared.startMonitoring()
    }
}

/// Parks a mounted tab without tearing it down.
///
/// Opacity lives on this wrapper so a hop can hide the leaving page without
/// re-diffing it. Inner `FrozenKeepAliveContent` skips `body` while a tab
/// stays in back, and on leave unless `refreshOnHide` (911 GPS / NFC
/// `isVisible` must still run). Front tab always re-diffs so Keychain /
/// environment land. Native pages hide at opacity 0 (Preview WKWebView is a
/// full-screen cover).
private struct IsolatedKeepAliveTab<Content: View>: View {
    let isFront: Bool
    let parksWebView: Bool
    let epoch: UInt
    let refreshOnHide: Bool
    let content: Content

    var body: some View {
        FrozenKeepAliveContent(
            epoch: epoch,
            isFront: isFront,
            refreshOnHide: refreshOnHide,
            content: content
        )
        .equatable()
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

private struct FrozenKeepAliveContent<Content: View>: View, Equatable {
    let epoch: UInt
    let isFront: Bool
    let refreshOnHide: Bool
    let content: Content

    static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.epoch == rhs.epoch else { return false }
        guard lhs.refreshOnHide == rhs.refreshOnHide else { return false }
        if lhs.isFront == rhs.isFront {
            // Stay in back: skip. Stay in front: always re-diff.
            return !lhs.isFront
        }
        if rhs.isFront { return false }
        // Becoming back: skip unless GPS / NFC visibility hooks need a pass.
        return !rhs.refreshOnHide
    }

    var body: some View { content }
}

struct CustomTabBar: View {
    @Binding var tab: AppTab
    var showsNFC: Bool = true
    /// Owner NFC tab tap — begin CoreNFC write on this gesture so hold finishes it.
    var onNFCWrite: (() -> Void)? = nil

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
            .padding(.top, 5)

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
        if tab == next {
            RedMedHaptics.selection()
            // Re-tap NFC → open write sheet again so hold can finish / retry.
            if next == .nfc {
                onNFCWrite?()
            }
            return
        }
        RedMedHaptics.selection()
        // No withAnimation on AppTab — that marks the content ZStack transaction even
        // when mounted tabs suppress animation, and fights opacity keep-alive.
        tab = next
        if next == .nfc {
            onNFCWrite?()
        }
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

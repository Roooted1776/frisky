import Combine
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
    /// Lazy: returning cold Main must not construct NFCWriter/Reader + Combine
    /// until first NFC tab mount or Write gesture. `ensure()` stays synchronous
    /// so CoreNFC `session.begin()` can still ride the gesture stack when
    /// `AppConfig.nfcHardwareEnabled` is restored (paid Apple Developer).
    @StateObject private var nfcBandBox = NFCBandBox()

    /// Passerby / Preview always get Aid. NFC is owner-only.
    private var showsAid: Bool { true }
    private var showsNFC: Bool { !isScannerSession }

    private var activeTab: AppTab { scannerSafeTab.wrappedValue }

    private var scannerSafeTab: Binding<AppTab> {
        Binding(
            get: {
                if !showsNFC && tab == .nfc { return .redmed }
                if !showsAid && tab == .aid { return .redmed }
                return tab
            },
            set: { newValue in
                // Mount in the same turn as `tab` — `onChange` ran *after* the
                // first body pass, so 911 / Aid / NFC painted empty cream on
                // first tap (the unreliable load).
                var next = newValue
                if !showsNFC && next == .nfc { next = .redmed }
                if !showsAid && next == .aid { next = .redmed }
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
                if showsAid {
                    mountedTab(.aid) { AidView() }
                }
                if showsNFC {
                    mountedTab(.nfc, refreshOnHide: true) {
                        NFCView(isVisible: activeTab == .nfc, band: nfcBandBox.ensure())
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, RedMedChrome.tabBarHeight)

            CustomTabBar(tab: scannerSafeTab, showsAid: showsAid, showsNFC: showsNFC, onNFCWrite: {
                startHoldToWriteFromNFCTab()
            })
        }
        .ignoresSafeArea(edges: .bottom)
        .task {
            guard !isScannerSession else { return }
            // Prefetch + MainActor adopt usually started in ProfileData.init
            // (may have filled RAM before this task). restoreOnLaunch is a
            // no-op when adopt already won. Haptics / CoreMotion / WK stay
            // past Face ID (Main is armed under cream — gate on interactive
            // + UIApplication.active, not a fixed sleep).
            RedMedSignpost.coldMark("restoreOnLaunch start")
            await profile.restoreOnLaunch()
            RedMedSignpost.coldMark("restoreOnLaunch done")
            guard !Task.isCancelled else { return }
            // String-only tapper.html read — safe during Face ID (no WK).
            PasserbyHTMLCardView.scheduleShellWarmOnce()
            await Task.yield()
            // No fixed sleep — waitUntilInteractive / waitUntilActive already
            // keep WK, Taptic, and CoreMotion off the Face ID cream. A 400ms
            // pause after restore only delayed post-unlock warm when Face ID
            // finished early (common on returning cold with prefetch).
            await OwnerSessionGate.waitUntilInteractive()
            guard !Task.isCancelled, OwnerSessionGate.isInteractive else { return }
            await RedMedMainPace.waitUntilActive()
            guard !Task.isCancelled else { return }
            await Task.yield()
            RedMedHaptics.prepare()
            startCrashMonitorIfOwner()
            // Spare full (non-embed) WKWebView for first NFC Preview / Scan —
            // only after unlock; never during Face ID.
            guard !isScannerSession else { return }
            PasserbyWebViewPool.warmFullShell()
            RedMedSignpost.coldMark("post-interactive warm (haptics/motion/WK)")
            // Next-screen catalogs so first Aid topic / Edit keystroke is ready.
            Task.detached(priority: .userInitiated) {
                await AidTopicCatalog.warmUp()
                await SuggestionCatalog.warmUp()
            }
        }
        .onAppear {
            mountedTabs.insert(activeTab)
            clampScannerTab()
            // Same-turn mount in scannerSafeTab already paints 911 / Aid / NFC
            // on first tap. Do not pre-stack those pages under RedMed — that
            // kept GPS / Aid catalog / NFC WK warm compositing for the session.
            // Crash monitor + haptics start after restore in `.task`.
        }
        .onChange(of: scenePhase) { _, phase in
            guard !isScannerSession else { return }
            switch phase {
            case .active:
                // Do not outrun Keychain restore on cold open.
                guard !profile.isRestoringFromKeychain else { return }
                // Face ID cream arms Main early — wait for unlock.
                guard OwnerSessionGate.isInteractive else { return }
                startCrashMonitorIfOwner()
            case .background:
                // Hard stop on true background. No short grace /
                // beginBackgroundTask linger — CoreMotion dies on
                // suspend anyway, and there is no motion background
                // mode. Armed siren (audio) is independent.
                CrashMotionGuard.shared.stopMonitoring()
            default:
                // Only intentional “still around for a moment” path:
                // Face ID (post-Agree / Edit / Save / Erase / Load From
                // Band), Control Center, app switcher peek. Keep
                // listening. Do not invent a post-Home window.
                break
            }
        }
        .onChange(of: tab) { _, newTab in
            mountedTabs.insert(newTab)
            if newTab != .nfc {
                nfcBandBox.cancelSessions()
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
        // Associated Domains: foreign `#d=` presents via
        // `BandTapIngress` above ConsentGate (ungated). NFC Scan still uses
        // scannedCard on this tree after owner Face ID.
        .fullScreenCover(item: nfcBandBox.scannedCardBinding) { session in
            PasserbyHTMLCardView(
                payloadOrURL: session.payload,
                braceletLinked: profile.showsBraceletAsLinked,
                embedProfileJSON: session.embedJSON
            )
            .environment(\.isScannerSession, true)
            .presentationBackground(Color.redmedBg)
        }
        .presentsOwnerHelp()
    }

    /// Open the CoreNFC write sheet on the NFC-tab / Write CTA stack.
    /// Hold the band ~1–2″ finishes the program — iOS has no silent write.
    /// Parked: no-op — Write The Band stays disabled until Tag Reading ships.
    private func startHoldToWriteFromNFCTab() {
        guard showsNFC, !isScannerSession, AppConfig.nfcHardwareEnabled else { return }
        guard profile.hasSensitiveProfileData else { return }
        nfcBandBox.ensure().writeBand(from: profile, isScannerSession: false)
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
        if !showsAid && tab == .aid {
            tab = .redmed
        }
    }

    /// Owner Main only. Scanner / passerby never start CoreMotion.
    private func startCrashMonitorIfOwner() {
        guard !isScannerSession else { return }
        CrashMotionGuard.shared.startMonitoring()
    }
}

/// Owns `NFCBandManager` only after first NFC use (tab mount or Write).
/// Avoids CoreNFC ObservableObject + Combine sink cost on returning cold Main
/// when only the RedMed tab is mounted. Creation is synchronous for the
/// gesture-stack Write path when hardware is later re-enabled.
@MainActor
private final class NFCBandBox: ObservableObject {
    private var instance: NFCBandManager?
    private var forward: AnyCancellable?

    func ensure() -> NFCBandManager {
        if let instance { return instance }
        let band = NFCBandManager()
        instance = band
        forward = band.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        objectWillChange.send()
        return band
    }

    /// Universal Link / scan cover — nil until `ensure()` (cold Main stays cheap).
    var scannedCardBinding: Binding<NFCBandManager.ScannedCardSession?> {
        Binding(
            get: { self.instance?.scannedCard },
            set: { self.instance?.scannedCard = $0 }
        )
    }

    func cancelSessions() {
        instance?.cancelSessions()
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
        // opacity 0 alone still left Help in the AX tree (UITest saw 3× Help).
        .accessibilityHidden(!isFront)
        .accessibilityElement(children: isFront ? .contain : .ignore)
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
        guard lhs.refreshOnHide == rhs.refreshOnHide else { return false }
        if lhs.isFront == rhs.isFront {
            // Parked: skip even when cardEpoch bumps (Save / identical
            // Face ID reload). Front always re-diffs so YOU fills land.
            if !lhs.isFront { return true }
            return false
        }
        if rhs.isFront { return false }
        // Becoming back: skip unless GPS / NFC visibility hooks need a pass.
        return !rhs.refreshOnHide
    }

    var body: some View { content }
}

struct CustomTabBar: View {
    @Binding var tab: AppTab
    var showsAid: Bool = true
    var showsNFC: Bool = true
    /// Owner NFC tab tap or re-tap — begin CoreNFC write on this gesture.
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
                if showsAid {
                    TabBarItem(icon: "cross.case.fill", label: "Aid", isOn: tab == .aid) {
                        select(.aid)
                    }
                }
                if showsNFC {
                    TabBarItem(icon: "wave.3.right", label: "NFC", isOn: tab == .nfc) {
                        select(.nfc)
                    }
                }
            }
            // Extra top pad (5→10) — roomier chrome so tab hops are easier to land.
            .padding(.top, 10)

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
                .allowsHitTesting(false)
        }
        // Bar bounds only — upward shadow must not eat YOU-card / list taps.
        .contentShape(barShape)
        .accessibilityElement(children: .contain)
        // Warm Taptic before first press — covers owner + scanner shells
        // (ContentView.task skips prepare when isScannerSession).
        .onAppear { RedMedHaptics.prepare() }
    }

    private func select(_ next: AppTab) {
        // Selection haptic fires on press via TabBarItem (instant), not here.
        if tab == next {
            // Re-tap NFC → open write sheet again so hold can finish / retry.
            if next == .nfc {
                onNFCWrite?()
            }
            return
        }
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
            // Fixed icon (32) + gap (2) + label (12) = 46 — same row height on
            // every tab inside a 52pt hit column. Shrink-to-fit "RedMed" stays
            // inside the label slot so it cannot pull the baseline below
            // 911 / Aid / NFC.
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isOn ? .semibold : .regular))
                    .symbolRenderingMode(isCompass ? .hierarchical : .monochrome)
                    .foregroundStyle(tint)
                    .frame(width: 32, height: 32, alignment: .center)
                    .background(
                        RoundedRectangle(cornerRadius: RedMedChrome.chipRadius, style: .continuous)
                            .fill(isOn ? Color.redmedAccent.opacity(0.12) : Color.clear)
                    )
                    .accessibilityHidden(true)
                Text(label)
                    .font(.system(size: 10, weight: isOn ? .semibold : .medium))
                    .foregroundColor(tint)
                    .kerning(-0.1)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .multilineTextAlignment(.center)
                    .frame(height: 12, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            // Full column hit target — without contentShape, only glyph/text pixels
            // register taps and tabs feel too tight. 52pt clears the 44pt floor.
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .center)
            .contentShape(Rectangle())
            // Discrete tint swap — no spring/bounce on every tab hop.
            .transaction { $0.animation = nil }
        }
        // Instant press + selection haptic on finger-down (not release).
        .buttonStyle(RedMedPressStyle(
            scale: 0.98,
            haptic: { RedMedHaptics.selection() },
            animates: false
        ))
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint(isOn ? "Selected" : "Switch to \(label)")
    }
}

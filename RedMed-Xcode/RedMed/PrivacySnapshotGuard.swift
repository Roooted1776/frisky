import SwiftUI
import UIKit

/// Hides PHI from iOS app-switcher snapshots and active screen capture / mirroring.
/// Apply at the owner window root. The passerby **tap card** (Preview / Scan /
/// `PasserbyHTMLCardView`) must stay readable — never cover it. Helpers need
/// that YOU card unblocked. Cover owner chrome when backgrounded or recorded.
///
/// FaceTime / Screen Recording sets `UIScreen.isCaptured`. Do **not** cover the
/// lock / Unlock shell — RAM is purged then, and a cover blocks Face ID /
/// Unlock so the owner cannot enter. Do **not** cover the tap card — that is
/// the public EMT view. Cover only when PHI is actually in memory and the tap
/// card is not up. `OwnerAppLock` stages Keychain decode without publishing
/// fields until after `gate = .unlocked`, so capture never paints a cover over
/// the lock shell.
///
/// Non-capture SwiftUI cover is **`.background` only** (with PHI). Face ID /
/// LAContext put the scene `.inactive` — covering then blanks the UI mid-unlock
/// and painted a second cover over the cream lock. App-switcher snapshots
/// still get a cover on true background while PHI is in RAM; after
/// `OwnerAppLock` purges, the lock shell itself has no PHI to leak.
///
/// In-app pages stay uncovered while the owner is using them. The cream
/// overlay is the app-switcher thumbnail (`SnapshotSafeCover`) plus this
/// background/capture veil — never a persistent layer on live tabs.
struct PrivacySnapshotGuard<Content: View>: View {
    @EnvironmentObject private var profile: ProfileData
    @Environment(\.scenePhase) private var scenePhase
    /// Default false — read `UIScreen.isCaptured` after first paint (see onAppear).
    @State private var screenCaptured = false
    /// Cold launch reports `.inactive` before first `.active`. Covering then paints
    /// a blank shell over the real UI and reads as a long hang after the launch screen.
    @State private var hasBeenActive = false
    /// Preview / Scan tap card is the public EMT view — never veil it.
    /// Literal default — do not read MainActor / TapCardPresentation in `@State`.
    @State private var tapCardVisible = false
    @ViewBuilder private var content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    private var phiInMemory: Bool {
        profile.hasSensitiveProfileData || profile.holdsEditingSession
    }

    private var mustCover: Bool {
        // Tap card (Preview / Scan / band-style shell) stays readable — never cover.
        if tapCardVisible { return false }
        // Capture cover only while PHI is resident — lock / Unlock must stay tappable.
        if screenCaptured {
            return phiInMemory
        }
        // Stay uncovered until the first active frame so tabs paint immediately.
        guard hasBeenActive else { return false }
        // App-switcher / true background only — Face ID / LAContext put the scene
        // `.inactive` and would blank the UI mid-unlock (same rule as VaultHistoryView).
        guard scenePhase == .background else { return false }
        return phiInMemory
    }

    var body: some View {
        ZStack {
            content()

            // No opacity animation — iOS may capture the switcher snapshot while a
            // fade is mid-flight, leaking PHI under a translucent cover.
            if mustCover {
                privacyCover
                    .zIndex(999)
            }
        }
        .onAppear {
            tapCardVisible = TapCardPresentation.isVisible
            screenCaptured = UIScreen.main.isCaptured
            if scenePhase == .active {
                hasBeenActive = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                hasBeenActive = true
            } else if phase == .background, hasBeenActive {
                // Clear on true background only — `.inactive` (Control Center /
                // app switcher peek) would wipe coords before the user can paste.
                SecurePasteboard.clear()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .redMedTapCardPresentationDidChange)) { _ in
            tapCardVisible = TapCardPresentation.isVisible
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            let nowCaptured = UIScreen.main.isCaptured
            screenCaptured = nowCaptured
            if nowCaptured {
                SecurePasteboard.clear()
                // Don't log a cover we refused to paint over the tap card.
                if phiInMemory, !tapCardVisible {
                    VaultHistoryStore.shared.record(.screenCaptureCovered, detail: "share")
                }
            }
        }
    }

    private var privacyCover: some View {
        ZStack {
            Color.redmedBg.ignoresSafeArea()
            VStack(spacing: 12) {
                // Cream only — no BrandLogo / wordmark on the cover (PHI snapshot).
                Text(screenCaptured ? "Hidden while screen sharing" : "Profile hidden")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedMuted)
                if screenCaptured {
                    Text("Stop FaceTime screen share or Screen Recording to view your profile.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Covers the key window with cream **synchronously** on `willResignActive` —
/// before iOS captures the app-switcher thumbnail — so PHI can never leak
/// into that snapshot. This is the **only** cream overlay while the owner
/// is still on live pages: it is a switcher snapshot veil, not a page
/// chrome. `OwnerAppLock` no longer swaps the tab tree for `LockEntryPage`
/// on `.inactive` (that painted cream on top of pages). Face ID runs on
/// the next `.active` (re-entry). The cover stays up across that handoff
/// (`holdSwitcherCover`) so `didBecomeActive` cannot flash one frame of PHI
/// before the lock shell + Face ID sheet take over.
///
/// Removed once Face ID unlocks (or if the owner never left). Fires on
/// every app switch (`.inactive` included — Control Center, app switcher,
/// an incoming call) because the snapshot risk exists at every one of
/// those transitions, not only true `.background`.
///
/// Skip covering while already locked — the cream lock shell is opaque
/// and has no PHI, and a UIKit cover on `willResignActive` (Face ID puts
/// the scene inactive) sat on top of **Proceed**.
final class SnapshotSafeCover {
    static let shared = SnapshotSafeCover()

    private var coverView: UIView?

    private init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.cover()
        }
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.uncover()
        }
    }

    /// No-op besides triggering `shared`'s lazy init — call once at app
    /// start so the observers are registered before the first resign.
    static func activate() {
        _ = shared
    }

    /// Drop the switcher veil after Face ID succeeds (or erase). Safe to
    /// call when no cover is up.
    func reveal() {
        coverView?.removeFromSuperview()
        coverView = nil
    }

    private func cover() {
        // Passerby tap card (Preview / Scan / band-style shell) is the public
        // EMT view — never veil it, matching PrivacySnapshotGuard's own rule.
        guard !TapCardPresentation.isVisible,
              !OwnerLockPresentation.isLocked,
              coverView == nil,
              let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)
        else { return }
        let view = UIView(frame: window.bounds)
        view.backgroundColor = UIColor(Color.redmedBg)
        view.isUserInteractionEnabled = false
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(view)
        coverView = view
    }

    private func uncover() {
        // Stay cream across the switcher → foreground handoff until
        // Face ID owns the lock shell. Dropping the cover on
        // didBecomeActive would flash PHI under the incoming tabs.
        if OwnerLockPresentation.holdSwitcherCover { return }
        reveal()
    }
}

/// Cream lock shell is already opaque and has no PHI. A UIKit cover on
/// `willResignActive` (Face ID puts the scene inactive) sat on top of
/// **Proceed** and made a hung evaluate look indefinite — watchdogs
/// showed the button, the cover hid it. Skip covering while locked.
enum OwnerLockPresentation {
    private static let lock = NSLock()
    private static var locked = true
    private static var holdCover = false

    static var isLocked: Bool {
        lock.lock()
        defer { lock.unlock() }
        return locked
    }

    static func setLocked(_ locked: Bool) {
        lock.lock()
        self.locked = locked
        lock.unlock()
    }

    /// Keep the UIKit switcher cream up until Face ID re-entry takes the
    /// lock shell. Prevents a PHI flash on `didBecomeActive`.
    static var holdSwitcherCover: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return holdCover
        }
        set {
            lock.lock()
            holdCover = newValue
            lock.unlock()
        }
    }
}

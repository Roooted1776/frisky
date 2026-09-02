import SwiftUI
import UIKit

/// Hides PHI from iOS app-switcher snapshots and active screen capture / mirroring.
/// Apply at the owner window root. The passerby **tap card** (Preview / Scan /
/// `PasserbyHTMLCardView`) must stay readable — never cover it. Helpers need
/// that YOU card unblocked. Cover owner chrome when backgrounded or recorded.
///
/// FaceTime / Screen Recording sets `UIScreen.isCaptured`. Do **not** cover the
/// tap card — that is the public EMT view. Cover only when PHI is actually in
/// memory and the tap card is not up. There is no cream lock in front of Main.
///
/// Non-capture SwiftUI cover is **`.background` only** (with PHI). Face ID /
/// LAContext on the RedMed user page / Edit / Save / Erase put the scene
/// `.inactive` — covering then blanks the UI mid-prompt. App-switcher
/// snapshots still get a cover on true background while PHI is in RAM.
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
    /// iOS can report UIScreen.isCaptured == true with nothing actually being
    /// recorded (iOS 26 platform bug). Lets the owner break out manually.
    @State private var manualCaptureOverride = false
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
        if screenCaptured {
            // Same .inactive rule as the non-capture path: Face ID / LAContext
            // on the RedMed user page / Edit / Save / Erase resigns the scene
            // and must not blank the UI mid-prompt. Cold start is also
            // .inactive — wait for first .active so a false
            // UIScreen.isCaptured (iOS 26) cannot cream the first paint.
            guard hasBeenActive, scenePhase == .active else { return false }
            return phiInMemory && !manualCaptureOverride
        }
        // Stay uncovered until the first active frame so tabs paint immediately.
        guard hasBeenActive else { return false }
        // App-switcher / true background only — Face ID / LAContext put the scene
        // `.inactive` and would blank the UI mid-prompt on the RedMed user
        // page / Edit / Save / Erase.
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
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                let nowCaptured = UIScreen.main.isCaptured
                if nowCaptured != screenCaptured {
                    screenCaptured = nowCaptured
                }
                if !nowCaptured {
                    manualCaptureOverride = false
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                hasBeenActive = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .redMedTapCardPresentationDidChange)) { _ in
            tapCardVisible = TapCardPresentation.isVisible
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            let nowCaptured = UIScreen.main.isCaptured
            screenCaptured = nowCaptured
            if !nowCaptured {
                manualCaptureOverride = false
            }
            if nowCaptured {
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
                Text(screenCaptured ? "Hidden While Screen Sharing" : "Profile Hidden")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedMuted)
                if screenCaptured {
                    Text("Stop FaceTime screen share or Screen Recording to view your profile.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                    Button("Not Sharing Your Screen? Tap To Unlock") {
                        manualCaptureOverride = true
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.redmedAccent)
                    .padding(.top, 4)
                }
            }
        }
        .accessibilityHidden(screenCaptured ? false : true)
    }
}

/// Covers the key window with cream **synchronously** on `willResignActive` —
/// before iOS captures the app-switcher thumbnail — so PHI can never leak
/// into that snapshot. This is the **only** cream overlay while the owner
/// is still on live pages: it is a switcher snapshot veil, not a page
/// chrome. There is no cream lock swapping the tab tree on `.inactive`.
///
/// Removed when the owner is back on live pages (or if they never left). Fires on
/// every app switch (`.inactive` included — Control Center, app switcher,
/// an incoming call) because the snapshot risk exists at every one of
/// those transitions, not only true `.background`.
///
/// Face ID on the RedMed user page / Edit / Save / Erase also resigns active.
/// The system sheet sits above this window cover; `didBecomeActive` drops it
/// when the prompt ends.
final class SnapshotSafeCover {
    static let shared = SnapshotSafeCover()

    private var coverView: UIView?
    /// Cold launch / Xcode debugger attach fire willResignActive before the
    /// first Main frame. Covering then is the cream hang after the launch screen.
    private var hasBeenActive = false

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
            self?.hasBeenActive = true
            self?.uncover()
        }
    }

    /// No-op besides triggering `shared`'s lazy init — call once at app
    /// start so the observers are registered before the first resign.
    static func activate() {
        _ = shared
    }

    /// Drop the switcher veil. Safe to call when no cover is up.
    func reveal() {
        coverView?.removeFromSuperview()
        coverView = nil
    }

    private func cover() {
        // Wait for the first active frame so launch / debugger attach
        // cannot paint cream over Main.
        guard hasBeenActive else { return }
        // Passerby tap card (Preview / Scan / band-style shell) is the public
        // EMT view — never veil it, matching PrivacySnapshotGuard's own rule.
        guard !TapCardPresentation.isVisible,
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
        reveal()
    }
}

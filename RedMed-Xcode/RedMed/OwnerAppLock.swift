import SwiftUI
import UIKit

/// Owner-app Face ID gate. System prompt only — no LockEntryPage, FacePage,
/// or Proceed. Locked layer is the launch heart (cream + BrandLogo) so Face
/// ID sits on that same screen. Never wraps passerby tapper / public NFC card.
///
/// First start (no stored consent, or policy version bump): Face ID, then
/// Before you continue, then Agree → Main.
/// Every later entry (cold open, kill/reopen, Home, app-switch): Face ID,
/// then Main. Relock whenever the owner app leaves the foreground.
struct OwnerAppLock<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var profile: ProfileData
    @ViewBuilder var content: () -> Content

    private enum Gate {
        case locked
        case unlocked
    }

    /// Always start locked — including Simulator. Sim `BiometricAuth` already
    /// auto-succeeds same-turn (no UIKit Authenticate alert). Device never
    /// auto-succeeds.
    @State private var gate: Gate = .locked
    @State private var isAuthenticating = false
    /// Keep Main / ack mounted after the first success so tab switches and
    /// later Face ID do not remount 911 / Aid / NFC.
    @State private var didUnlockOnce = false
    @State private var authGeneration = 0
    /// True after this lock cycle has actually called `evaluatePolicy`.
    /// Prevents a Cancel → `.active` loop from re-prompting immediately.
    @State private var didPromptThisLock = false
    @State private var notInteractiveRetried = false
    @State private var inactiveLockTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            if didUnlockOnce || gate == .unlocked {
                content()
                    .accessibilityHidden(gate != .unlocked)
                    .allowsHitTesting(gate == .unlocked)
            }
            if gate == .locked {
                // Same layer as UILaunchScreen: cream + BrandLogo heart.
                // Face ID sits on this, not after a blank cream hang.
                ZStack {
                    Color.redmedBg.ignoresSafeArea()
                    Image("BrandLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 180, height: 180)
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    tryPromptFaceID(force: true)
                }
            }
        }
        .onAppear {
            OwnerLockPresentation.setLocked(true)
            OwnerLockPresentation.holdSwitcherCover = true
            tryPromptFaceID()
        }
        .onChange(of: scenePhase) { _, phase in
            handleScenePhase(phase)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIWindow.didBecomeKeyNotification)) { _ in
            if gate == .locked {
                tryPromptFaceID()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .redMedDidEraseLocalData)) { _ in
            // Wipe → acknowledgment → Main. Stay unlocked; do not Face ID again.
            inactiveLockTask?.cancel()
            isAuthenticating = false
            didPromptThisLock = true
            OwnerLockPresentation.setLocked(false)
            OwnerLockPresentation.holdSwitcherCover = false
            SnapshotSafeCover.shared.reveal()
            didUnlockOnce = true
            gate = .unlocked
        }
    }

    private func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .inactive:
            // Face ID / passcode sheets also drive `.inactive`. Do not relock
            // while evaluate is live — that kills the system prompt.
            inactiveLockTask?.cancel()
            guard gate == .unlocked, !isAuthenticating, !BiometricAuth.isEvaluating else {
                return
            }
            OwnerLockPresentation.holdSwitcherCover = true
            // App switcher often stays `.inactive` without `.background`.
            // Lock after a short beat so a Control Center flicker can return
            // without a prompt, but a real leave still re-locks. Missing an
            // app-switch is worse than a second Face ID.
            inactiveLockTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 250_000_000)
                guard !Task.isCancelled else { return }
                guard scenePhase != .active else { return }
                guard gate == .unlocked else { return }
                guard !isAuthenticating, !BiometricAuth.isEvaluating else { return }
                relock(cancelEvaluate: false)
            }
        case .background:
            inactiveLockTask?.cancel()
            OwnerLockPresentation.holdSwitcherCover = true
            relock(cancelEvaluate: true)
        case .active:
            inactiveLockTask?.cancel()
            if gate == .unlocked {
                OwnerLockPresentation.holdSwitcherCover = false
                SnapshotSafeCover.shared.reveal()
            } else {
                tryPromptFaceID()
            }
        @unknown default:
            break
        }
    }

    /// Lock so the next foreground always runs a real Face ID on device.
    /// Does not unmount content after the first unlock (tabs stay warm).
    private func relock(cancelEvaluate: Bool) {
        SecurePasteboard.clear()
        BiometricAuth.clearAuthenticationContext()
        if cancelEvaluate {
            BiometricAuth.cancelInFlight()
        }
        authGeneration &+= 1
        isAuthenticating = false
        didPromptThisLock = false
        notInteractiveRetried = false
        OwnerLockPresentation.setLocked(true)
        OwnerLockPresentation.holdSwitcherCover = true
        CrashMotionGuard.shared.stopMonitoring()
        gate = .locked
    }

    private var hasKeyWindow: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .contains(where: \.isKeyWindow)
    }

    private func tryPromptFaceID(force: Bool = false) {
        guard gate == .locked else { return }
        guard !isAuthenticating else { return }
        guard scenePhase != .background else { return }
        if !force, didPromptThisLock { return }
        // Device: wait for `.active` + key window. Evaluating during cold-start
        // `.inactive` returns notInteractive, then a 280ms retry — that is the
        // extra hang on the heart. Simulator auto-succeeds same-turn.
        #if !targetEnvironment(simulator)
        guard scenePhase == .active else { return }
        guard hasKeyWindow else { return }
        #endif
        unlockWithFaceID()
    }

    private func unlockWithFaceID() {
        guard gate == .locked, !isAuthenticating else { return }
        isAuthenticating = true
        didPromptThisLock = true
        authGeneration &+= 1
        let generation = authGeneration
        RedMedSignpost.trace("OwnerAppLock evaluate generation=\(generation)")
        RedMedSignpost.begin(.faceIDEvaluate)
        // Face ID first. Prefetch after evaluate is in flight — Keychain.exists
        // / shell warm on this turn delayed the sheet on the heart.
        BiometricAuth.authenticate(
            reason: "Unlock RedMed",
            force: true,
            allowPasscode: true
        ) { outcome in
            RedMedSignpost.end(.faceIDEvaluate)
            // LA delivers on the main *queue*, not the MainActor *executor*.
            // Sync `@State` writes here (Thread.isMainThread) trap under Swift
            // concurrency — same post–Face ID load crash as #296 / #307.
            Task { @MainActor in
                guard generation == authGeneration else { return }
                handleUnlockOutcome(outcome, generation: generation)
            }
        }
        profile.beginLaunchPrefetch()
        PasserbyHTMLCardView.scheduleShellWarmOnce()
    }

    private func handleUnlockOutcome(_ outcome: BiometricAuth.Outcome, generation: Int) {
        guard generation == authGeneration else { return }
        isAuthenticating = false
        switch outcome {
        case .success:
            OwnerLockPresentation.setLocked(false)
            OwnerLockPresentation.holdSwitcherCover = false
            SnapshotSafeCover.shared.reveal()
            didUnlockOnce = true
            gate = .unlocked
            CrashMotionGuard.shared.startMonitoring()
        case .notInteractive:
            // Cold-launch race: scene not interactive for LA yet. One
            // bounded retry after LAContext teardown. Same-turn retry is a
            // dead prompt.
            gate = .locked
            if !notInteractiveRetried {
                scheduleNotInteractiveRetry(generation: generation)
            } else {
                didPromptThisLock = true
            }
        case .declined, .notVerified, .timedOut, .unavailable:
            // Stay cream. No Proceed. Next leave+return or a cream tap retries.
            gate = .locked
            didPromptThisLock = true
        }
    }

    private func scheduleNotInteractiveRetry(generation: Int) {
        notInteractiveRetried = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard generation == authGeneration, gate == .locked else { return }
            guard !isAuthenticating else { return }
            guard scenePhase != .background else { return }
            didPromptThisLock = false
            tryPromptFaceID(force: true)
        }
    }
}

import SwiftUI

/// Owner app lock — Face ID / Touch ID / device passcode before PHI is published.
/// Passerby tapper / Main stay ungated. Every time the owner opens the app
/// (cold launch, Home, app switcher) this gate prompts again.
///
/// Keychain profile is biometry-bound (`KeychainStore`); Face ID parks an
/// `LAContext` so SecItem can read without a second sheet. Background clears
/// the park. Prefetch without context only resolves legacy unbound blobs.
///
/// **Warm rules:** `PasserbyHTMLCardView.warmShellCache()` (string) may overlap
/// Face ID. Do **not** create a WKWebView during Face ID (cream hang). After
/// unlock, the live RedMed tab loads from that string cache — do not start a
/// second pooled WK on the same turn (it races first paint).
/// `PasserbyWebViewPool.warmFullShell()` (NFC Scan / Preview's non-embed
/// shell) is a *separate* WKWebView pool from the RedMed tab's — it is safe
/// to warm shortly after unlock and does not touch that first-paint path.
struct OwnerAppLock<Content: View>: View {
    @EnvironmentObject private var profile: ProfileData
    @Environment(\.scenePhase) private var scenePhase
    @ViewBuilder var content: () -> Content

    private enum Gate {
        case locked
        case unlocked
    }

    @State private var gate: Gate = .locked
    @State private var isAuthenticating = false
    @State private var biometryFailed = false
    @State private var faceIDUnavailableReason: BiometricAuth.UnavailableReason?
    @State private var profileLoadFailed = false
    @State private var notInteractive = false
    @State private var keychainHasProfile = ProfileData.prefersLockOnLaunch
    @State private var authGeneration = 0
    @State private var screenCaptured = false
    @State private var didAutoPromptThisLock = false
    /// Guards the single automatic retry after a `.notInteractive` result —
    /// see the retry block in `unlockWithFaceID()`'s completion handler.
    @State private var notInteractiveRetried = false
    @State private var showUnlockControl = false
    /// When the current lock cycle actually started (cold launch or re-lock) —
    /// the watchdog below counts down from this, not from each retry's own
    /// `authGeneration` bump, so a fast-fail + retry can't stack a second
    /// full 8s window on top of the first and read as a ~9s+ hang.
    @State private var lockCycleStartedAt: Date?
    /// Bumped once per lock cycle (cold launch or re-lock). Identifies which
    /// cycle a scheduled `hardWatchdog` GCD block belongs to, independent of
    /// `authGeneration` (which bumps per Face ID attempt, not per cycle).
    @State private var lockCycleID = 0

    var body: some View {
        ZStack {
            switch gate {
            case .unlocked:
                content()
            case .locked:
                // Face ID / passcode sheet is the only chrome while evaluating.
                // FacePage (Proceed) only after cancel / mismatch / timeout.
                if showUnlockControl, !isAuthenticating {
                    FacePage(
                        screenCaptured: screenCaptured,
                        biometryFailed: biometryFailed,
                        unavailableReason: faceIDUnavailableReason,
                        profileLoadFailed: profileLoadFailed,
                        notInteractive: notInteractive,
                        onProceed: { startUnlockPipeline() },
                        onOpenSettings: {
                            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                            UIApplication.shared.open(url)
                        }
                    )
                } else {
                    LockEntryPage()
                }
            }
        }
        .transaction { $0.animation = nil }
        .onAppear {
            // Diagnostic only — see RedMedSignpost.swift. Ended below wherever
            // the lock screen first resolves (unlocked, or Proceed shown).
            RedMedSignpost.begin(.coldLaunchWindow)
            screenCaptured = UIScreen.main.isCaptured
            lockCycleStartedAt = Date()
            scheduleHardWatchdog()
            tryAutoUnlockIfActive()
            profile.beginUnlockPrefetch()
            // String cache only — not WK — during Face ID window. .utility so it
            // does not contend with the Face ID sheet for CPU on cold launch.
            Task.detached(priority: .utility) {
                PasserbyHTMLCardView.warmShellCache()
            }
        }
        .task(id: authGeneration) {
            guard gate == .locked else { return }
            let generation = authGeneration
            // Was 15s — that read as a hard hang (blank cream, nothing to tap)
            // on a cold launch where the system sheet never presents. 8s still
            // gives a real Face ID prompt (and a slower human) room to resolve
            // normally without cutting it off mid-interaction.
            //
            // Budgeted from `lockCycleStartedAt`, not from this generation's
            // own start — the fast-fail-then-retry path bumps authGeneration
            // (restarting this `.task`) partway through the cycle, and a
            // fresh 8s here on top of the first attempt's time already spent
            // stacked into a ~9s+ wait before the fallback screen ever
            // appeared. Counting down from the shared start caps the whole
            // cycle at 8s regardless of how many retries happen inside it.
            let elapsed = Date().timeIntervalSince(lockCycleStartedAt ?? Date())
            let remaining = max(0, 8.0 - elapsed)
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            guard gate == .locked, generation == authGeneration else { return }
            if isAuthenticating {
                // Hung Face ID sheet — kill it so Proceed can start a new one.
                BiometricAuth.cancelInFlight()
                isAuthenticating = false
            }
            showUnlockControl = true
        }
        .task {
            // .utility: this fires at cold launch alongside the Face ID prompt
            // itself — userInitiated contends with the system Face ID sheet for
            // CPU and delays it showing (same rule as ProfileData.beginUnlockPrefetch).
            let hasProfile = await Task.detached(priority: .utility) {
                ProfileData.hasStoredProfile()
            }.value
            ProfileData.setStoredProfileGate(hasProfile)
            keychainHasProfile = hasProfile
            if hasProfile {
                if gate == .locked {
                    profile.beginUnlockPrefetch()
                }
            } else {
                profile.discardUnlockPrefetch()
            }
            tryAutoUnlockIfActive()
        }
        .onChange(of: gate) { _, newGate in
            if newGate == .locked {
                didAutoPromptThisLock = false
                notInteractiveRetried = false
                showUnlockControl = false
                BiometricAuth.clearAuthenticationContext()
                tryAutoUnlockIfActive()
            } else {
                RedMedSignpost.end(.coldLaunchWindow)
                Task { @MainActor in
                    await Task.yield()
                    CrashMotionGuard.shared.startMonitoring()
                }
                // Distinct WKWebView from the RedMed tab's own load (which
                // uses the string cache, not a pool) — deferred well past
                // that first paint so NFC Scan / Preview stops paying full
                // cold-start cost on its first open. Never during Face ID.
                // Tried gating this on a "RedMed shell didFinish" signal
                // instead of a flat delay — didFinish fires before RedMed's
                // JS has actually settled the first paint, so warming a
                // second WKWebView right then still stole MainActor and
                // produced the same white/stuck-first-page hang this delay
                // exists to avoid. Back to the flat delay.
                Task(priority: .utility) { @MainActor in
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    PasserbyWebViewPool.warmFullShell()
                }
            }
        }
        .onChange(of: showUnlockControl) { _, shown in
            // Lock screen resolved into the manual Proceed screen — the other
            // resolution (unlocked) is handled in the gate onChange above.
            if shown {
                RedMedSignpost.end(.coldLaunchWindow)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive:
                // Face ID / system auth sheets also drive `.inactive`. Relocking
                // then kills the sheet and loops. Only relock when the owner
                // actually left an unlocked session (app switcher, Control
                // Center, incoming overlay) so the next open always prompts.
                if gate == .unlocked, !isAuthenticating, !BiometricAuth.isEvaluating {
                    relockAfterLeavingApp(cancelEvaluate: false)
                }
            case .background:
                relockAfterLeavingApp(cancelEvaluate: true)
            case .active:
                if gate == .locked {
                    tryAutoUnlockIfActive()
                }
            @unknown default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            screenCaptured = UIScreen.main.isCaptured
        }
        .onReceive(NotificationCenter.default.publisher(for: .redMedDidEraseLocalData)) { _ in
            keychainHasProfile = false
            biometryFailed = false
            faceIDUnavailableReason = nil
            profileLoadFailed = false
            notInteractive = false
            isAuthenticating = false
            didAutoPromptThisLock = false
            notInteractiveRetried = false
            showUnlockControl = false
            profile.discardUnlockPrefetch()
            BiometricAuth.clearAuthenticationContext()
            gate = .unlocked
        }
    }

    /// Lock + purge so the next open always gets a Face ID / passcode prompt.
    private func relockAfterLeavingApp(cancelEvaluate: Bool) {
        SecurePasteboard.clear()
        BiometricAuth.clearAuthenticationContext()
        if cancelEvaluate {
            // Kill any Face ID sheet the OS is about to cancel anyway
            // (backgrounding mid-scan) and bump authGeneration so that
            // cancelled evaluate's completion (which the OS still calls,
            // usually as `.declined`) cannot land after we reset below —
            // without this, that stale completion set `showUnlockControl
            // = true`, which then blocked `tryAutoUnlockIfActive`'s guard
            // on the very next foreground and left the user stuck on the
            // static Proceed page instead of an automatic Face ID prompt.
            BiometricAuth.cancelInFlight()
        }
        authGeneration &+= 1
        isAuthenticating = false
        showUnlockControl = false
        didAutoPromptThisLock = false
        notInteractiveRetried = false
        if gate == .unlocked {
            profile.purgeFromMemory()
            BiometricAuth.resetLaunchUnlock()
            lockCycleStartedAt = Date()
            gate = .locked
            scheduleHardWatchdog()
        }
        profile.discardUnlockPrefetch()
        PasserbyWebViewPool.cancelWarm()
    }

    /// Plain-GCD fallback for the `.task(id: authGeneration)` watchdog above.
    ///
    /// That watchdog is Swift's structured concurrency `Task` machinery —
    /// this app's "cream hang" bug has resurfaced enough times across enough
    /// different fixes (see file header / git history) that it is worth not
    /// trusting a single mechanism to always resolve the lock screen. A
    /// `DispatchQueue.main.asyncAfter` timer is not a `Task`: it cannot be
    /// cancelled by view-identity churn, structured-concurrency cancellation
    /// propagation, or actor hops, so it fires on a completely independent
    /// path even if the `Task`-based watchdog is ever skipped or silently
    /// cancelled for a reason this file's many prior fixes did not cover.
    /// Keyed to `lockCycleID` (bumped once per lock cycle), not
    /// `authGeneration` (bumped once per Face ID attempt), so a fast-fail
    /// retry inside the same cycle does not rearm a second overlapping timer.
    private func scheduleHardWatchdog() {
        lockCycleID &+= 1
        let cycleID = lockCycleID
        DispatchQueue.main.asyncAfter(deadline: .now() + 8.5) {
            guard gate == .locked, cycleID == lockCycleID else { return }
            if isAuthenticating {
                BiometricAuth.cancelInFlight()
                isAuthenticating = false
            }
            showUnlockControl = true
        }
    }

    private func tryAutoUnlockIfActive() {
        guard gate == .locked, !didAutoPromptThisLock, !showUnlockControl else { return }
        // Fire immediately, including on cold-start `.inactive` — per AGENTS.md,
        // waiting for `.active` is itself the cream-hang bug: the scene reaches
        // `.active` a beat after `.inactive`, and a blank cream LockEntryPage
        // with no Face ID sheet yet reads as a hang for that whole gap. A
        // `.notInteractive` evaluate (system genuinely can't present yet) still
        // recovers via a bounded retry / Proceed, so it costs nothing to try early.
        guard scenePhase != .background else { return }
        didAutoPromptThisLock = true
        startUnlockPipeline()
    }

    private func startUnlockPipeline() {
        guard gate == .locked else { return }
        didAutoPromptThisLock = true
        showUnlockControl = false
        unlockWithFaceID()
        profile.beginUnlockPrefetch()
        // String warm only during Face ID — WK waits until after unlock. .utility
        // so it does not compete with the Face ID sheet itself for CPU.
        Task.detached(priority: .utility) {
            PasserbyHTMLCardView.warmShellCache()
        }
    }

    private func unlockWithFaceID() {
        guard gate == .locked, !isAuthenticating else { return }
        isAuthenticating = true
        biometryFailed = false
        faceIDUnavailableReason = nil
        profileLoadFailed = false
        notInteractive = false
        authGeneration &+= 1
        let generation = authGeneration
        let attemptStartedAt = Date()
        RedMedSignpost.begin(.faceIDEvaluate)
        BiometricAuth.authenticate(
            reason: "Unlock RedMed",
            force: true,
            allowPasscode: true
        ) { outcome in
            // Ends right where the system call actually returns — isolates
            // Apple's own LocalAuthentication cost from anything RedMed does
            // afterward in this same completion.
            RedMedSignpost.end(.faceIDEvaluate)
            if case .success = outcome {
                // Start the parked-context Keychain read before the MainActor
                // hop so SecItem overlaps the SwiftUI turn instead of following it.
                profile.beginUnlockPrefetchWithParkedContext()
            }
            Task { @MainActor in
                guard generation == authGeneration else { return }
                switch outcome {
                case .declined:
                    isAuthenticating = false
                    biometryFailed = false
                    faceIDUnavailableReason = nil
                    profileLoadFailed = false
                    gate = .locked
                    let failedFast = Date().timeIntervalSince(attemptStartedAt) < 1.0
                    if !notInteractiveRetried, failedFast {
                        scheduleFastNotInteractiveRetry(generation: generation)
                    } else {
                        // User cancelled — Proceed with no error line.
                        notInteractive = false
                        didAutoPromptThisLock = false
                        showUnlockControl = true
                    }
                case .notInteractive:
                    isAuthenticating = false
                    biometryFailed = false
                    faceIDUnavailableReason = nil
                    profileLoadFailed = false
                    gate = .locked
                    let failedFast = Date().timeIntervalSince(attemptStartedAt) < 1.0
                    if !notInteractiveRetried, failedFast {
                        scheduleFastNotInteractiveRetry(generation: generation)
                    } else {
                        notInteractive = true
                        didAutoPromptThisLock = false
                        showUnlockControl = true
                    }
                case .notVerified:
                    RedMedHaptics.error()
                    isAuthenticating = false
                    biometryFailed = true
                    faceIDUnavailableReason = nil
                    notInteractive = false
                    showUnlockControl = true
                    gate = .locked
                    VaultHistoryStore.shared.record(.unlockFailed, detail: "appLock")
                case .unavailable(let reason):
                    // Retrying evaluatePolicy the same way never resolves
                    // this — no system Face ID sheet even shows for it. Tell
                    // the user which specific thing to fix instead of a
                    // generic "try again" that can't ever succeed.
                    RedMedHaptics.error()
                    isAuthenticating = false
                    biometryFailed = false
                    faceIDUnavailableReason = reason
                    notInteractive = false
                    showUnlockControl = true
                    gate = .locked
                    VaultHistoryStore.shared.record(.unlockFailed, detail: "appLock-unavailable")
                case .success:
                    guard generation == authGeneration else { return }
                    // Prefetch already kicked off in the authenticate
                    // callback (before this hop). Adopt it here.
                    await applyUnlockSuccess(generation: generation)
                }
            }
        }
    }

    /// One bounded retry for the cold-launch `.notInteractive` race.
    ///
    /// Never retry on the same turn as the failed evaluate — LAContext
    /// teardown needs ~0.28s wall clock (AGENTS.md). A same-turn retry
    /// fails immediately with no Face ID sheet (dead prompt). Do not treat
    /// `UIApplication.shared.applicationState == .active` as ready either;
    /// that can be true while the scene still isn't interactive for LA.
    private func scheduleFastNotInteractiveRetry(generation: Int) {
        notInteractiveRetried = true
        didAutoPromptThisLock = true
        let retryGeneration = generation
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard retryGeneration == authGeneration, gate == .locked else { return }
            guard !isAuthenticating, !showUnlockControl else { return }
            guard scenePhase != .background else { return }
            unlockWithFaceID()
        }
    }

    @MainActor
    private func applyUnlockSuccess(generation: Int) async {
        guard generation == authGeneration else { return }
        if tryFinishWithParkedUnlock(generation: generation) { return }
        async let expectsProfileTask = keychainHasProfile
            ? true
            : await Task.detached(priority: .userInitiated) {
                ProfileData.hasStoredProfile()
            }.value
        let didLoad = await profile.prepareUnlockPrefetchOrReload()
        let expectsProfile = didLoad ? true : await expectsProfileTask
        finishUnlockAfterAuth(
            generation: generation,
            didLoad: didLoad,
            expectsProfile: expectsProfile
        )
    }

    @MainActor
    private func tryFinishWithParkedUnlock(generation: Int) -> Bool {
        PasserbyWebViewPool.cancelWarm()
        guard let didLoad = profile.tryPrepareUnlockPrefetchSync() else {
            return false
        }
        if !didLoad, !keychainHasProfile { return false }
        // Bound item may have parked empty before LAContext existed — do not fail closed.
        if !didLoad, keychainHasProfile { return false }
        finishUnlockAfterAuth(
            generation: generation,
            didLoad: didLoad,
            expectsProfile: didLoad ? true : keychainHasProfile
        )
        return true
    }

    @MainActor
    private func finishUnlockAfterAuth(
        generation: Int,
        didLoad: Bool,
        expectsProfile: Bool
    ) {
        guard generation == authGeneration else {
            profile.discardUnlockPrefetch()
            profile.purgeFromMemory()
            BiometricAuth.clearAuthenticationContext()
            return
        }
        isAuthenticating = false
        if didLoad {
            keychainHasProfile = true
            gate = .unlocked
            profile.commitUnlockProfile()
            biometryFailed = false
            faceIDUnavailableReason = nil
            profileLoadFailed = false
            notInteractive = false
            showUnlockControl = false
            // Live RedMed tab loads from the Face ID string cache. A pooled
            // WK on this turn races first paint.
            RedMedHaptics.success()
        } else if !expectsProfile {
            keychainHasProfile = false
            profile.prepareEmptyUnlockShell()
            gate = .unlocked
            biometryFailed = false
            faceIDUnavailableReason = nil
            profileLoadFailed = false
            notInteractive = false
            showUnlockControl = false
            RedMedHaptics.success()
        } else {
            RedMedHaptics.error()
            gate = .locked
            biometryFailed = false
            faceIDUnavailableReason = nil
            profileLoadFailed = true
            notInteractive = false
            showUnlockControl = true
            BiometricAuth.clearAuthenticationContext()
        }
    }
}

import SwiftUI
import UIKit

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
    /// True from the moment Face ID/passcode succeeds until the profile
    /// finishes decoding and `gate` flips to `.unlocked`. Distinct from
    /// `isAuthenticating` (LAContext evaluate in flight) — conflating the
    /// two made a stuck Keychain decode look like a hung Face ID sheet to
    /// both watchdogs below, and made Proceed re-prompt an already-passed
    /// Face ID instead of retrying the actual stuck step.
    @State private var isLoadingProfile = false
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
            RedMedSignpost.trace("onAppear: gate=\(gate)")
            RedMedSignpost.begin(.coldLaunchWindow)
            screenCaptured = UIScreen.main.isCaptured
            lockCycleStartedAt = Date()
            logLock("onAppear hasKeyWindow=\(hasKeyWindow)")
            scheduleHardWatchdog()
            tryAutoUnlockIfActive()
            deferredWarmUp()
        }
        .task(id: authGeneration) {
            guard gate == .locked else { return }
            let generation = authGeneration
            // Was 15s, then 8s — both still read as a hard hang (blank cream,
            // nothing to tap) on a cold launch where the system sheet never
            // presents at all. When that happens there is no in-progress
            // Face ID / passcode sheet to interrupt (the user sees nothing,
            // full stop), so a shorter timeout does not risk cutting off a
            // real, slower human mid-interaction the way it would if a sheet
            // were actually up — it only shortens the blank-cream wait for
            // the no-sheet failure mode this watchdog exists to catch.
            //
            // Budgeted from `lockCycleStartedAt`, not from this generation's
            // own start — the fast-fail-then-retry path bumps authGeneration
            // (restarting this `.task`) partway through the cycle, and a
            // fresh window here on top of the first attempt's time already
            // spent would stack into a longer wait than intended before the
            // fallback screen ever appeared. Counting down from the shared
            // start caps the whole cycle regardless of how many retries
            // happen inside it.
            let elapsed = Date().timeIntervalSince(lockCycleStartedAt ?? Date())
            let remaining = max(0, 4.5 - elapsed)
            RedMedSignpost.trace("task watchdog armed: generation=\(generation) remaining=\(remaining)")
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
            RedMedSignpost.trace("task watchdog woke: generation=\(generation) currentGen=\(authGeneration) gate=\(gate)")
            guard gate == .locked, generation == authGeneration else { return }
            if isAuthenticating {
                // Hung Face ID sheet — kill it so Proceed can start a new one.
                BiometricAuth.cancelInFlight()
                isAuthenticating = false
            } else if isLoadingProfile {
                // Face ID already succeeded — only the Keychain/profile
                // decode is stuck. Say so specifically so Proceed retries
                // that instead of re-prompting an already-passed Face ID.
                profileLoadFailed = true
            }
            showUnlockControl = true
            RedMedSignpost.trace("task watchdog forced showUnlockControl=true")
        }
        .task {
            // .utility priority alone wasn't enough to rule out contention
            // with the system Face ID sheet's very first presentation tick —
            // also stagger this off the exact instant evaluatePolicy fires,
            // same as `deferredWarmUp()` below.
            try? await Task.sleep(nanoseconds: 300_000_000)
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
        .onReceive(NotificationCenter.default.publisher(for: UIWindow.didBecomeKeyNotification)) { _ in
            // Cold launch: `onAppear` can fire before any window is key yet,
            // and `tryAutoUnlockIfActive` no-ops in that case rather than
            // calling `evaluatePolicy` early (see its doc comment). This is
            // the retry that actually starts Face ID once a window exists —
            // usually only milliseconds behind `onAppear`, not the unbounded
            // `.active` wait that caused the earlier version of this bug.
            logLock("windowDidBecomeKey")
            tryAutoUnlockIfActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: .redMedDidEraseLocalData)) { _ in
            keychainHasProfile = false
            biometryFailed = false
            faceIDUnavailableReason = nil
            profileLoadFailed = false
            notInteractive = false
            isAuthenticating = false
            isLoadingProfile = false
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
        isLoadingProfile = false
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
        RedMedSignpost.trace("GCD watchdog armed: cycleID=\(cycleID)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            RedMedSignpost.trace("GCD watchdog woke: cycleID=\(cycleID) currentCycle=\(lockCycleID) gate=\(gate)")
            guard gate == .locked, cycleID == lockCycleID else { return }
            logLock("hard watchdog fired isAuthenticating=\(isAuthenticating)")
            if isAuthenticating {
                BiometricAuth.cancelInFlight()
                isAuthenticating = false
            } else if isLoadingProfile {
                profileLoadFailed = true
            }
            showUnlockControl = true
            RedMedSignpost.trace("GCD watchdog forced showUnlockControl=true")
        }
    }

    #if DEBUG
    private func logLock(_ message: String) {
        let elapsed = Date().timeIntervalSince(lockCycleStartedAt ?? Date())
        print(String(format: "[OwnerAppLock] +%.3fs %@", elapsed, message))
    }
    #else
    private func logLock(_ message: String) {}
    #endif

    private func tryAutoUnlockIfActive() {
        RedMedSignpost.trace("tryAutoUnlockIfActive: gate=\(gate) didAutoPrompt=\(didAutoPromptThisLock) showUnlockControl=\(showUnlockControl) scenePhase=\(scenePhase)")
        guard gate == .locked, !didAutoPromptThisLock, !showUnlockControl else { return }
        // Fire immediately, including on cold-start `.inactive` — per AGENTS.md,
        // waiting for `.active` is itself the cream-hang bug: the scene reaches
        // `.active` a beat after `.inactive`, and a blank cream LockEntryPage
        // with no Face ID sheet yet reads as a hang for that whole gap. A
        // `.notInteractive` evaluate (system genuinely can't present yet) still
        // recovers via a bounded retry / Proceed, so it costs nothing to try early.
        guard scenePhase != .background else { return }
        // But do not call evaluatePolicy before any window is key — on cold
        // launch `onAppear` can fire that early, and unlike `.notInteractive`
        // (a synchronous, fast rejection this file already retries), a call
        // made before a key window exists has been observed to just sit —
        // no success, no error — until the watchdogs below kill it,
        // which reads as this app's "cream hang" on every single launch
        // rather than only occasionally. `UIWindow.didBecomeKeyNotification`
        // above retries this the moment a window exists, normally only
        // milliseconds behind this earliest attempt.
        guard hasKeyWindow else { return }
        didAutoPromptThisLock = true
        startUnlockPipeline()
    }

    private var hasKeyWindow: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .contains(where: \.isKeyWindow)
    }

    private func startUnlockPipeline() {
        guard gate == .locked else { return }
        if showUnlockControl {
            // Manual retry from the Proceed screen — give this attempt its
            // own fresh watchdog budget. Both watchdogs otherwise still
            // count down from the *original* cold-launch `lockCycleStartedAt`
            // / `lockCycleID`, which can already be exhausted (clamped to 0
            // remaining) by the time the user taps Proceed. Without this
            // reset, the `.task(id: authGeneration)` watchdog restarted by
            // `unlockWithFaceID()` below fires almost instantly and calls
            // `BiometricAuth.cancelInFlight()`, killing the fresh Face ID
            // sheet before it can even present — every subsequent Proceed
            // tap repeats this and reads as an indefinite stuck cream
            // screen, since Face ID never gets a real chance to show.
            lockCycleStartedAt = Date()
            scheduleHardWatchdog()
        }
        if isLoadingProfile {
            // Face ID already succeeded on the abandoned attempt — the
            // profile decode was the stuck step, so retry that instead of
            // re-prompting an already-passed Face ID (which would also
            // orphan the first attempt's in-flight `applyUnlockSuccess`).
            retryStuckProfileLoad()
            return
        }
        didAutoPromptThisLock = true
        showUnlockControl = false
        logLock("startUnlockPipeline")
        unlockWithFaceID()
        deferredWarmUp()
    }

    /// Re-attempts the profile decode after a watchdog flagged it stuck —
    /// never re-runs Face ID here, since biometrics already succeeded for
    /// the generation this is resuming.
    private func retryStuckProfileLoad() {
        profileLoadFailed = false
        showUnlockControl = false
        let generation = authGeneration
        Task { @MainActor in
            await applyUnlockSuccess(generation: generation)
            guard generation == authGeneration, gate == .locked else { return }
            // Still stuck — surface it again rather than leaving a blank
            // cream screen with no live watchdog left to catch it.
            isLoadingProfile = false
            profileLoadFailed = true
            showUnlockControl = true
        }
    }

    /// String cache + profile prefetch during the Face ID window — `.utility`
    /// priority alone did not rule out contending with the system sheet's
    /// very first presentation tick on cold launch, so both also wait 300ms
    /// past the `evaluatePolicy` call before starting, giving Face ID a
    /// clear first shot. The Keychain prefetch is the more suspect of the
    /// two — it is a SecItem query, closer to whatever subsystem Face ID
    /// itself uses, unlike the shell cache's plain bundled-file read. Still
    /// finishes well before a real Face ID / human interaction completes in
    /// the common case, so the Face-ID-overlap speedup these exist for is
    /// barely affected. Shell warm goes through `scheduleShellWarmOnce()` so
    /// this call and the one from `onAppear` (both of which reach
    /// `deferredWarmUp()`) don't each spawn their own redundant task.
    private func deferredWarmUp() {
        Task.detached(priority: .utility) {
            try? await Task.sleep(nanoseconds: 300_000_000)
            PasserbyHTMLCardView.scheduleShellWarmOnce()
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            profile.beginUnlockPrefetch()
        }
    }

    private func unlockWithFaceID() {
        RedMedSignpost.trace("unlockWithFaceID: gate=\(gate) isAuthenticating=\(isAuthenticating)")
        guard gate == .locked, !isAuthenticating else { return }
        isAuthenticating = true
        // Clear any stale flag from an abandoned prior generation (e.g. a
        // Proceed retry started here while that generation's profile decode
        // was still stuck) — this attempt's own success sets it fresh.
        isLoadingProfile = false
        biometryFailed = false
        faceIDUnavailableReason = nil
        profileLoadFailed = false
        notInteractive = false
        authGeneration &+= 1
        let generation = authGeneration
        let attemptStartedAt = Date()
        logLock("unlockWithFaceID calling BiometricAuth.authenticate generation=\(generation)")
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
            RedMedSignpost.trace("BiometricAuth.authenticate completion: outcome=\(outcome) generation=\(generation) thread=\(Thread.isMainThread ? "main" : "bg")")
            if case .success = outcome {
                // Start the parked-context Keychain read before the MainActor
                // hop so SecItem overlaps the SwiftUI turn instead of following it.
                profile.beginUnlockPrefetchWithParkedContext()
            }
            Task { @MainActor in
                guard generation == authGeneration else { return }
                logLock("unlockWithFaceID completion outcome=\(outcome) elapsed=\(Date().timeIntervalSince(attemptStartedAt))")
                switch outcome {
                case .timedOut:
                    // 45s already elapsed with no callback at all — this is
                    // OwnerAppLock's own much faster watchdogs' territory and
                    // they almost always win the race first; this branch only
                    // matters if they're somehow disarmed. No fast-retry
                    // escalation (unlike `.declined`/`.notInteractive` below):
                    // that much time has already passed, so just let Proceed
                    // start a fresh attempt.
                    isAuthenticating = false
                    biometryFailed = false
                    faceIDUnavailableReason = nil
                    profileLoadFailed = false
                    notInteractive = false
                    didAutoPromptThisLock = false
                    gate = .locked
                    showUnlockControl = true
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
                    // Face ID/passcode is done — from here on a stall is the
                    // profile decode, not the sheet. Let the watchdogs know.
                    isAuthenticating = false
                    isLoadingProfile = true
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
        // Bound item may have parked empty before LAContext existed, or there may
        // genuinely be no profile yet — either way defer to the slower async path in
        // applyUnlockSuccess, which re-checks `ProfileData.hasStoredProfile()` off-main
        // instead of trusting this synchronous parked read alone.
        if !didLoad { return false }
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
        isLoadingProfile = false
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

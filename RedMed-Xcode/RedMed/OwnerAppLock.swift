import SwiftUI

/// Owner app lock — Face ID / Touch ID before PHI is published into profile fields.
/// No passcode / password pad on this gate (tapper / Main are next).
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
    @State private var showUnlockControl = false

    var body: some View {
        ZStack {
            switch gate {
            case .unlocked:
                content()
            case .locked:
                if showUnlockControl {
                    FacePage(
                        screenCaptured: screenCaptured,
                        biometryFailed: biometryFailed,
                        unavailableReason: faceIDUnavailableReason,
                        profileLoadFailed: profileLoadFailed,
                        notInteractive: notInteractive,
                        isAuthenticating: isAuthenticating,
                        onProceed: { startUnlockPipeline(isAuto: false) },
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
            screenCaptured = UIScreen.main.isCaptured
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
            try? await Task.sleep(nanoseconds: 8_000_000_000)
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
                showUnlockControl = false
                BiometricAuth.clearAuthenticationContext()
                tryAutoUnlockIfActive()
            } else {
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
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                SecurePasteboard.clear()
                // Drop SecItem auth session — next read needs Face ID again.
                BiometricAuth.clearAuthenticationContext()
                // Kill any Face ID sheet the OS is about to cancel anyway
                // (backgrounding mid-scan) and bump authGeneration so that
                // cancelled evaluate's completion (which the OS still calls,
                // usually as `.declined`) cannot land after we reset below —
                // without this, that stale completion set `showUnlockControl
                // = true`, which then blocked `tryAutoUnlockIfActive`'s guard
                // on the very next foreground and left the user stuck on the
                // static Proceed page instead of an automatic Face ID prompt.
                BiometricAuth.cancelInFlight()
                authGeneration &+= 1
                isAuthenticating = false
                showUnlockControl = false
                didAutoPromptThisLock = false
                if gate == .unlocked {
                    // Re-lock on background — Home / app switcher / a real
                    // backgrounding all require Face ID again on return, not
                    // just at cold launch. `.background` only (never
                    // `.inactive`, same rule as the vault): a Face ID /
                    // system auth sheet also puts the scene `.inactive` and
                    // must not trip this. Purge PHI from memory now so
                    // nothing lingers behind the lock screen while backgrounded.
                    profile.purgeFromMemory()
                    // Without this, BiometricAuth's own "already unlocked this
                    // launch" fast-path silently short-circuits the next
                    // unlockWithFaceID() call to .success with no Face ID
                    // sheet at all (unlockWithFaceID never passes force:true
                    // by design) — the re-lock would then have no real way
                    // back in.
                    BiometricAuth.resetLaunchUnlock()
                    gate = .locked
                }
                profile.discardUnlockPrefetch()
                PasserbyWebViewPool.cancelWarm()
            } else if phase == .active, gate == .locked {
                tryAutoUnlockIfActive()
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
            showUnlockControl = false
            profile.discardUnlockPrefetch()
            BiometricAuth.clearAuthenticationContext()
            gate = .unlocked
        }
    }

    private func tryAutoUnlockIfActive() {
        guard gate == .locked, !didAutoPromptThisLock, !showUnlockControl else { return }
        // Fire immediately, including on cold-start `.inactive` — per AGENTS.md,
        // waiting for `.active` is itself the cream-hang bug: the scene reaches
        // `.active` a beat after `.inactive`, and a blank cream LockEntryPage
        // with no Face ID sheet yet reads as a hang for that whole gap. A
        // `.notInteractive` evaluate (system genuinely can't present yet) still
        // recovers via the Proceed screen, so it costs nothing to try early.
        guard scenePhase != .background else { return }
        didAutoPromptThisLock = true
        startUnlockPipeline(isAuto: true)
    }

    private func startUnlockPipeline(isAuto: Bool) {
        guard gate == .locked else { return }
        if isAuto {
            didAutoPromptThisLock = true
            showUnlockControl = false
        }
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
        BiometricAuth.authenticate(
            reason: "Unlock RedMed",
            allowPasscode: false
        ) { outcome in
            Task { @MainActor in
                guard generation == authGeneration else { return }
                switch outcome {
                case .declined:
                    isAuthenticating = false
                    biometryFailed = false
                    faceIDUnavailableReason = nil
                    notInteractive = false
                    showUnlockControl = true
                    gate = .locked
                case .notInteractive:
                    isAuthenticating = false
                    biometryFailed = false
                    faceIDUnavailableReason = nil
                    profileLoadFailed = false
                    // System couldn't present the Face ID sheet (backgrounded,
                    // interrupted, another modal in flight). Tell the user
                    // so Proceed doesn't look like a dead button.
                    notInteractive = true
                    gate = .locked
                    didAutoPromptThisLock = false
                    // Force Face on screen. The cold-launch auto attempt
                    // starts with showUnlockControl already false — "leave
                    // as-is" there means LockEntryPage (no button, no text)
                    // stays up forever with nothing left to retry it.
                    showUnlockControl = true
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
                    // Bound Keychain needs the parked LAContext. Restart the
                    // Face ID-overlapped load now — the pre-park attempt fails
                    // closed without a sheet (kSecUseAuthenticationUIFail).
                    profile.beginUnlockPrefetchWithParkedContext()
                    await applyUnlockSuccess(generation: generation)
                }
            }
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

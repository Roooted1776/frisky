import SwiftUI

/// Owner app lock — Face ID / Touch ID before PHI is published into profile fields.
/// No passcode / password pad on this gate (tapper / Main are next).
///
/// On background after first unlock: stay in Main (no second Face ID).
/// PrivacySnapshotGuard still covers snapshots while PHI is in RAM.
/// Scanner / passerby shells never mount this — they use
/// `ProfileData(persisting: false)` snapshots only.
///
/// Prefetch may decode Keychain + pack `#d=` off-main while Face ID runs; that
/// work stays off `@Published` until auth succeeds (or is discarded on cancel /
/// background). Late Face ID success after a generation bump must not apply.
///
/// Cold launch never touches Keychain on the first frame. The lock shell always
/// paints first; SecItem confirms off-main whether a profile blob exists (for
/// prefetch / fail-closed load) but does **not** open Main without auth.
///
/// Every owner launch is Face ID before Main (no passcode pad). Front page is
/// `LockEntryPage`: cream + Higgs `FaceIDFrame` clip, first Face ID, then Main.
/// After cancel / mismatch, **Face** (`FacePage`) with **Proceed** replaces
/// that shell. No second Face ID this process after success (Edit / NFC / vault
/// skip). Erase still prompts. No LockOpen clip.
/// Fresh install unlocks into empty tabs after auth; returning owners load
/// Keychain (fail closed on corrupt blob). Auto-prompt once per lock —
/// including cold launch while still `.inactive` (waiting for `.active` was
/// the cream hang: empty cream with no sheet). Face ID sheets put the scene
/// `.inactive` — `didAutoPromptThisLock` blocks re-prompt.
///
/// Speed (minus Face ID wall time): Face ID kicks first; Keychain prefetch +
/// tapper.html string warm start in the same `onAppear` tick and again inside
/// the unlock pipeline (single-flight). Parked Keychain adopt unlocks on the
/// LA main-queue turn via `MainActor.assumeIsolated` (no Task hop). Face page
/// is solid cream (no material blur). Haptic + WKWebView warm run at utility
/// priority after `gate = .unlocked` so Main paints first.
struct OwnerAppLock<Content: View>: View {
    @EnvironmentObject private var profile: ProfileData
    @Environment(\.scenePhase) private var scenePhase
    @ViewBuilder var content: () -> Content

    private enum Gate {
        case locked
        case unlocked
    }

    /// Always locked on first frame — Main never mounts before Face ID.
    @State private var gate: Gate = .locked
    @State private var isAuthenticating = false
    /// True only after Face ID / Touch ID (or passcode) mismatch — never on cancel
    /// or cold launch, and never for Keychain decode failure.
    @State private var biometryFailed = false
    @State private var profileLoadFailed = false
    @State private var hasEverHadSensitiveData = ProfileData.prefersLockOnLaunch
    /// Keychain presence from the off-main check — unlock into empty tabs when false.
    @State private var keychainHasProfile = ProfileData.prefersLockOnLaunch
    /// Bumps on lock so a late Face ID success cannot unlock after background.
    @State private var authGeneration = 0
    /// Default false — read capture state after first paint (see onAppear).
    @State private var screenCaptured = false
    /// One auto Face ID per lock session — blocks inactive→active re-entry loops.
    @State private var didAutoPromptThisLock = false
    /// Face page after cancel / mismatch. First load = Face ID sheet only.
    @State private var showUnlockControl = false

    var body: some View {
        ZStack {
            switch gate {
            case .unlocked:
                content()
            case .locked:
                if showUnlockControl {
                    FacePage(
                        playing: scenePhase != .background,
                        screenCaptured: screenCaptured,
                        biometryFailed: biometryFailed,
                        profileLoadFailed: profileLoadFailed,
                        isAuthenticating: isAuthenticating,
                        onProceed: { startUnlockPipeline(isAuto: false) }
                    )
                } else {
                    LockEntryPage(playing: scenePhase != .background)
                }
            }
        }
        // Instant lock ↔ Main — no soft fade (reads as lag / stuck cream).
        .transaction { $0.animation = nil }
        .onAppear {
            screenCaptured = UIScreen.main.isCaptured
            // Face ID first — cream hang waiting for `.active` or shell warm is wasted time.
            tryAutoUnlockIfActive()
            // Always prefetch (single-flight). Do not gate on UserDefaults — stale/false
            // gate left Face ID overlapping nothing.
            profile.beginUnlockPrefetch()
            Task.detached(priority: .userInitiated) {
                PasserbyHTMLCardView.warmShellCache()
            }
        }
        .task(id: authGeneration) {
            // Hung LA — Face page with Proceed (do not leave a dead Face ID sheet).
            guard gate == .locked else { return }
            let generation = authGeneration
            try? await Task.sleep(nanoseconds: 15_000_000_000)
            guard gate == .locked, generation == authGeneration else { return }
            if isAuthenticating {
                isAuthenticating = false
            }
            showUnlockControl = true
        }
        .task {
            // First SwiftUI frame already committed — Keychain presence can wait.
            // Presence only drives prefetch / fail-closed load — never skips the lock.
            let hasProfile = await Task.detached(priority: .userInitiated) {
                ProfileData.hasStoredProfile()
            }.value
            ProfileData.setStoredProfileGate(hasProfile)
            keychainHasProfile = hasProfile
            if hasProfile {
                hasEverHadSensitiveData = true
                // Face ID may already be running (onAppear kicked LA first) — still
                // start single-flight prefetch so unlock overlaps SecItem.
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
                tryAutoUnlockIfActive()
            } else {
                // Face ID success — yield so tabs paint before CoreMotion steals the CPU.
                Task { @MainActor in
                    await Task.yield()
                    CrashMotionGuard.shared.startMonitoring()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // First Face ID only — do not re-lock into a second sheet.
            // Cover still paints from PrivacySnapshotGuard while PHI is in RAM.
            if phase == .background {
                SecurePasteboard.clear()
                if gate == .locked {
                    profile.discardUnlockPrefetch()
                }
            } else if phase == .active, gate == .locked {
                // Cold `.inactive` Face ID is still the first unlock, not a retry gate.
                tryAutoUnlockIfActive()
            }
        }
        .onChange(of: profile.hasSensitiveProfileData) { _, hasData in
            if hasData { hasEverHadSensitiveData = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            screenCaptured = UIScreen.main.isCaptured
        }
        .onReceive(NotificationCenter.default.publisher(for: .redMedDidEraseLocalData)) { _ in
            hasEverHadSensitiveData = false
            keychainHasProfile = false
            biometryFailed = false
            profileLoadFailed = false
            isAuthenticating = false
            didAutoPromptThisLock = false
            showUnlockControl = false
            profile.discardUnlockPrefetch()
            // Stay in Main after an authenticated erase; next cold launch locks again.
            gate = .unlocked
        }
    }

    /// Front page is `LockEntryPage` — static cream, Face ID, then Main.
    private func tryAutoUnlockIfActive() {
        guard gate == .locked, !didAutoPromptThisLock, !showUnlockControl else { return }
        // Cold launch often starts `.inactive` before first `.active`. Waiting for
        // `.active` left a cream hang with no Face ID. Kick LA unless truly
        // backgrounded — `didAutoPromptThisLock` blocks re-prompt while the Face
        // ID sheet holds the scene `.inactive` (AGENTS: no re-prompt on inactive).
        guard scenePhase != .background else { return }
        didAutoPromptThisLock = true
        startUnlockPipeline(isAuto: true)
    }

    private func lock(purge: Bool) {
        authGeneration &+= 1
        gate = .locked
        isAuthenticating = false
        biometryFailed = false
        profileLoadFailed = false
        showUnlockControl = false
        if purge {
            profile.purgeFromMemory()
        }
        SecurePasteboard.clear()
    }

    /// Face ID first, then Keychain prefetch + shell string in the same turn
    /// (overlap while LA sheet is up). Enter path for returning owners — first
    /// attempt is auto Face ID only. Do **not** build WKWebView here — that
    /// races the post-auth Keychain await on MainActor (blank cream hang).
    private func startUnlockPipeline(isAuto: Bool) {
        guard gate == .locked else { return }
        if isAuto {
            didAutoPromptThisLock = true
            // First-load surface stays biometrics-only until this attempt ends.
            showUnlockControl = false
        }
        // Face ID first; prefetch still starts inside this pipeline (same turn).
        unlockWithFaceID()
        profile.beginUnlockPrefetch()
        // HTML string only during Face ID — WKWebView warm waits until unlock.
        Task.detached(priority: .userInitiated) {
            PasserbyHTMLCardView.warmShellCache()
        }
    }

    private func unlockWithFaceID() {
        guard gate == .locked, !isAuthenticating else { return }
        isAuthenticating = true
        biometryFailed = false
        profileLoadFailed = false
        authGeneration &+= 1
        let generation = authGeneration
        BiometricAuth.authenticate(
            reason: "Unlock RedMed",
            allowPasscode: false
        ) { outcome in
            guard generation == authGeneration else { return }
            switch outcome {
            case .declined:
                // Cancel — Face page with Proceed. Keep Keychain prefetch.
                isAuthenticating = false
                biometryFailed = false
                showUnlockControl = true
                gate = .locked
            case .notInteractive:
                // Cold-start evaluate before the window can present. Clear
                // auto-prompt so `.active` runs the first Face ID once.
                isAuthenticating = false
                biometryFailed = false
                profileLoadFailed = false
                gate = .locked
                didAutoPromptThisLock = false
                showUnlockControl = false
            case .notVerified:
                RedMedHaptics.error()
                isAuthenticating = false
                biometryFailed = true
                showUnlockControl = true
                gate = .locked
                VaultHistoryStore.shared.record(.unlockFailed, detail: "appLock")
            case .success:
                // Apply only if this generation is still current. Check again after
                // await — background can bump authGeneration and purge mid-apply.
                // LA completion is main-queue (`DispatchQueue.main`) but not
                // MainActor-isolated. Prefer `assumeIsolated` when already on
                // main so a parked Keychain adopt unlocks this turn (no Task hop).
                applyUnlockSuccess(generation: generation)
            }
        }
    }

    /// Fast path: parked Face ID decode on the current main turn.
    /// Slow path: `Task { @MainActor }` only when Keychain still needs an await.
    private func applyUnlockSuccess(generation: Int) {
        if Thread.isMainThread {
            let parked = MainActor.assumeIsolated {
                tryFinishWithParkedUnlock(generation: generation)
            }
            if parked { return }
        }

        Task { @MainActor in
            guard generation == authGeneration else { return }
            if tryFinishWithParkedUnlock(generation: generation) { return }
            // Off-main SecItem overlaps Keychain apply when the gate still says empty.
            async let expectsProfileTask = keychainHasProfile
                ? true
                : await Task.detached(priority: .userInitiated) {
                    ProfileData.hasStoredProfile()
                }.value
            // Keychain blob only — embed JSON is sync from the blob (no await).
            // Staging only: PHI fields stay empty until gate unlocks so
            // PrivacySnapshotGuard never covers the lock shell under capture.
            let didLoad = await profile.prepareUnlockPrefetchOrReload()
            let expectsProfile = didLoad ? true : await expectsProfileTask
            finishUnlockAfterAuth(
                generation: generation,
                didLoad: didLoad,
                expectsProfile: expectsProfile
            )
        }
    }

    /// Cancel stale WebKit warm + adopt Face ID–parked Keychain if ready.
    /// Returns `true` when unlock finished (hit or empty Keychain result).
    @MainActor
    private func tryFinishWithParkedUnlock(generation: Int) -> Bool {
        PasserbyWebViewPool.cancelWarm()
        guard let didLoad = profile.tryPrepareUnlockPrefetchSync() else {
            return false
        }
        finishUnlockAfterAuth(
            generation: generation,
            didLoad: didLoad,
            expectsProfile: didLoad ? true : keychainHasProfile
        )
        return true
    }

    /// Shared unlock finish for sync (parked) and async (Keychain await) paths.
    @MainActor
    private func finishUnlockAfterAuth(
        generation: Int,
        didLoad: Bool,
        expectsProfile: Bool
    ) {
        guard generation == authGeneration else {
            // Late success after background lock — drop staging, no PHI published.
            profile.discardUnlockPrefetch()
            profile.purgeFromMemory()
            return
        }
        isAuthenticating = false
        if didLoad {
            keychainHasProfile = true
            // Unlock shell first, then publish PHI in the same turn.
            gate = .unlocked
            profile.commitUnlockProfile()
            biometryFailed = false
            profileLoadFailed = false
            showUnlockControl = false
            // Haptic + WebKit off the critical path — Main paints first.
            Task(priority: .utility) { @MainActor in
                RedMedHaptics.success()
                PasserbyWebViewPool.warmEmbedShell()
            }
        } else if !expectsProfile {
            // Fresh install — auth passed; open empty Main (Edit gates Save).
            keychainHasProfile = false
            profile.prepareEmptyUnlockShell()
            gate = .unlocked
            biometryFailed = false
            profileLoadFailed = false
            showUnlockControl = false
            Task(priority: .utility) { @MainActor in
                RedMedHaptics.success()
                PasserbyWebViewPool.warmEmbedShell()
            }
        } else {
            // Corrupt / unreadable Keychain — stay locked; do not open empty Edit.
            RedMedHaptics.error()
            gate = .locked
            biometryFailed = false
            profileLoadFailed = true
            showUnlockControl = true
        }
    }
}

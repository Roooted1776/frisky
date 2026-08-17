import SwiftUI

/// Owner app lock — Face ID / passcode before PHI is published into profile fields.
///
/// On background / lock: profile fields are purged from RAM (Keychain untouched).
/// On unlock: reload from Keychain. Scanner / passerby shells never mount this —
/// they use `ProfileData(persisting: false)` snapshots only.
///
/// Prefetch may decode Keychain + pack `#d=` off-main while Face ID runs; that
/// work stays off `@Published` until auth succeeds (or is discarded on cancel /
/// background). Late Face ID success after a generation bump must not apply.
///
/// Cold launch never touches Keychain on the first frame. The lock shell always
/// paints first; SecItem confirms off-main whether a profile blob exists (for
/// prefetch / fail-closed load) but does **not** open Main without auth.
///
/// Every owner launch is Face ID / passcode before Main: cream + muted
/// `LockOpen` atmosphere video behind a small medical lock glyph (not BrandLogo,
/// not Apple Face ID mark). Path: open → auth → Main. Video never gates Face ID
/// or Main — missing file / Reduce Motion / Low Power = cream only. No Accept
/// step. No post-auth overlay (that clip-over-Main was the cream hang). Unlock
/// is retry chrome after cancel / mismatch only.
/// Fresh install unlocks into empty tabs after auth; returning owners load
/// Keychain (fail closed on corrupt blob). Auto-prompt once per lock —
/// including cold launch while still `.inactive` (waiting for `.active` was
/// the cream hang: empty cream with no sheet). Face ID sheets put the scene
/// `.inactive` — `didAutoPromptThisLock` blocks re-prompt.
///
/// Speed (minus Face ID wall time): Face ID kicks first; Keychain prefetch +
/// tapper.html string warm start in the same `onAppear` tick and again inside
/// the unlock pipeline (single-flight). Parked Keychain adopt unlocks on the
/// LA main-queue turn via `MainActor.assumeIsolated` (no Task hop). Unlock dock
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

    /// Always locked on first frame — Main never mounts before Face ID / passcode.
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
    /// Unlock control stays hidden until the first Face ID attempt ends (cancel /
    /// mismatch / load fail). First load = biometrics sheet only.
    @State private var showUnlockControl = false

    var body: some View {
        ZStack {
            switch gate {
            case .unlocked:
                content()
            case .locked:
                lockScreen
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
            // Hung LA only — do not flash Unlock under a live Face ID sheet.
            // Path is open → auth → Main; Unlock is cancel / mismatch / dead LA.
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
            // LAContext / system auth sheets put the scene `.inactive`.
            // Only purge + lock on true background (same rule as VaultHistoryView).
            if phase == .background,
               profile.hasSensitiveProfileData
                || hasEverHadSensitiveData
                || profile.holdsEditingSession
                || gate == .locked {
                profile.discardUnlockPrefetch()
                didAutoPromptThisLock = false
                showUnlockControl = false
                lock(purge: true)
            } else if phase == .active {
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

    /// Remodeled load shell: cream + muted LockOpen bloom behind a small
    /// medical glyph (no BrandLogo — AGENTS). Retry chrome is a floating cream
    /// dock. Face ID sheets hold `.inactive` — glyph only under the sheet;
    /// atmosphere video keeps playing (pause on `.background` only).
    /// After auth success: straight to Main — no clip overlay, no “Opening” dock.
    private var showsRetryDock: Bool {
        showUnlockControl || screenCaptured
    }

    private var lockScreen: some View {
        ZStack {
            lockAtmosphere

            // Quiet center while Face ID owns the sheet — functional glyph only.
            if !showsRetryDock {
                lockLoadGlyph
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            if showsRetryDock {
                lockRetryChrome
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("RedMed is locked")
    }

    /// Cream first paint, then muted LockOpen bloom behind the glyph.
    /// Static washes stay for Reduce Motion / missing clip. Video never waits
    /// Face ID or Main — AV starts on the next run loop; unlock tears it down
    /// without waiting for a frame or end.
    private var lockAtmosphere: some View {
        ZStack {
            Color.redmedBg
            if LockOpenClip.shouldPlay {
                LockAtmosphereVideo(playing: scenePhase != .background)
            } else {
                RadialGradient(
                    colors: [
                        Color.redmedWash.opacity(0.78),
                        Color.redmedWash.opacity(0.22),
                        Color.redmedBg.opacity(0)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.12),
                    startRadius: 12,
                    endRadius: 520
                )
                RadialGradient(
                    colors: [
                        Color.redmedAccent.opacity(0.07),
                        Color.redmedBg.opacity(0)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.92),
                    startRadius: 8,
                    endRadius: 340
                )
                LinearGradient(
                    colors: [
                        Color.redmedSurface.opacity(0.55),
                        Color.clear,
                        Color.redmedWash.opacity(0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Small medical lock mark under the system sheet — no cream disc so the
    /// atmosphere shows through. Spring pop only (no material / ProgressView).
    private var lockLoadGlyph: some View {
        LockMedGlyph()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .offset(y: -28)
            .allowsHitTesting(false)
    }

    /// Status + Unlock after cancel / mismatch (hidden on first Face ID prompt).
    /// Bottom sheet dock: solid cream surface, continuous corners.
    private var lockRetryChrome: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 16) {
                Capsule()
                    .fill(Color.redmedDark.opacity(0.14))
                    .frame(width: 36, height: 4)
                    .padding(.bottom, 2)

                if screenCaptured {
                    Text("Screen sharing is on — unlock with passcode. Profile stays hidden on the share until you stop sharing.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if biometryFailed {
                    Text("Couldn't verify it's you. Try again.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else if profileLoadFailed {
                    Text("Couldn't load your profile. Try again.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                } else if showUnlockControl {
                    Text("Unlock to open RedMed")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.redmedDark.opacity(0.78))
                        .multilineTextAlignment(.center)
                }

                if showUnlockControl {
                    unlockButton
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 26)
            .frame(maxWidth: .infinity)
            .background { unlockDockBackground }
            .padding(.horizontal, 14)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.identity)
    }

    /// Solid cream dock — no material blur (faster composite under/after Face ID).
    private var unlockDockBackground: some View {
        let shape = RoundedRectangle(cornerRadius: RedMedChrome.unlockDockRadius, style: .continuous)
        return shape
            .fill(Color.redmedSurface)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.redmedDivider
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)
    }

    private var unlockButton: some View {
        Button {
            RedMedHaptics.medium()
            startUnlockPipeline(isAuto: false)
        } label: {
            Group {
                if isAuthenticating {
                    // No ProgressView — system spinner fights first MainActor frames
                    // under / after Face ID and reads as a white hitch.
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Unlocking")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .accessibilityLabel("Unlocking with Face ID")
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Unlock")
                            .font(.system(size: 16, weight: .bold))
                    }
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: RedMedChrome.unlockButtonRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1, green: 0.447, blue: 0.537).opacity(0.75),
                                Color.redmedAccent.opacity(0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: RedMedChrome.unlockButtonRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.32), lineWidth: 1)
                    }
                    .shadow(color: RedMedChrome.accentShadow, radius: 12, y: 6)
            }
        }
        .buttonStyle(RedMedPressStyle(haptic: nil))
        .disabled(isAuthenticating)
        .accessibilityHint("Face ID, Touch ID, or passcode")
    }

    private func tryAutoUnlockIfActive() {
        guard gate == .locked, !didAutoPromptThisLock else { return }
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
            reason: "Unlock RedMed"
        ) { outcome in
            guard generation == authGeneration else { return }
            switch outcome {
            case .declined:
                // Cancel / dismiss — stay locked; Unlock appears for retry.
                // Keep Keychain prefetch — no PHI published until success; Unlock
                // tap must not cold-decode again (stuck / lag feel).
                isAuthenticating = false
                biometryFailed = false
                showUnlockControl = true
                gate = .locked
            case .notInteractive:
                // Cold-start evaluate before the window can present — do not leave
                // Unlock chrome up; clear auto-prompt so `.active` retries once.
                // User cancel is `.declined` (Unlock stays); this is not cancel.
                // Never auto-kick inline when already `.active` — LA can still return
                // notInteractive briefly and that looped Face ID forever.
                isAuthenticating = false
                biometryFailed = false
                profileLoadFailed = false
                gate = .locked
                didAutoPromptThisLock = false
                if scenePhase == .active {
                    // Already active but LA refused — Unlock, no retry storm.
                    showUnlockControl = true
                } else {
                    // Typical cold `.inactive` — `.onChange(.active)` retries once.
                    showUnlockControl = false
                }
                // Keep prefetch — Face ID will overlap on the active retry / Unlock tap.
            case .notVerified:
                // Face ID / Touch ID (or passcode) did not match.
                RedMedHaptics.error()
                isAuthenticating = false
                biometryFailed = true
                showUnlockControl = true
                gate = .locked
                // Keep prefetch for fast retry — staging is not published.
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

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
/// Every owner launch is Face ID / passcode before Main: flat cream only (no
/// BrandLogo, no load glyph, no sheet dock). No Accept step. Unlock is a large
/// centered retry after cancel / mismatch — hidden on the first Face ID attempt.
/// Face ID success mounts Main in the same turn and plays `LockOpen` full-bleed
/// over it (muted). Gate still has no fade — the clip is the transition.
/// Fresh install unlocks into empty tabs after auth; returning owners load
/// Keychain (fail closed on corrupt blob). Auto-prompt once per lock —
/// including cold launch while still `.inactive` (waiting for `.active` was the
/// cream hang: empty cream with no sheet). Face ID sheets put the scene
/// `.inactive` — `didAutoPromptThisLock` blocks re-prompt.
///
/// Speed (minus Face ID wall time): Face ID kicks first; Keychain prefetch +
/// tapper.html string warm start in the same `onAppear` tick and again inside
/// the unlock pipeline (single-flight). WKWebView warm starts **only after**
/// `gate = .unlocked` — warming during Face ID (or before the Keychain await)
/// stole MainActor while the LA sheet was dismissing and left a blank cream /
/// white hang after auth. Unlock does **not** wait on AES `#d=` or a finished
/// WebView — placeholder `#d=` + `__REDMED_PROFILE` paints RedMed; durable AES
/// finishes in background; warm continues best-effort after first paint.
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
    /// Full-page open clip — armed only on Face ID success, over already-mounted Main.
    @State private var playOpenOverlay = false
    @State private var openOverlayOpacity = 1.0

    var body: some View {
        ZStack {
            Group {
                switch gate {
                case .unlocked:
                    content()
                case .locked:
                    lockScreen
                }
            }
            // Instant lock ↔ Main — no soft fade (reads as lag / stuck cream).
            // Open clip sits on top of Main; it is not a gate animation.
            .transaction { $0.animation = nil }
            if playOpenOverlay {
                LockOpenOverlay {
                    dismissOpenOverlay()
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(openOverlayOpacity)
                .accessibilityHidden(true)
            }
        }
        .onAppear {
            screenCaptured = UIScreen.main.isCaptured
            LockOpenClip.prewarm()
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
            // Escape hatch: if LA never callbacks, Unlock must still be tappable.
            // Do not flash Unlock under a live Face ID sheet (common at ~1–2s).
            // Keep the blank-cream window short — long waits read as a white hang.
            guard gate == .locked else { return }
            let generation = authGeneration
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard gate == .locked, generation == authGeneration else { return }
            if isAuthenticating {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard gate == .locked, generation == authGeneration else { return }
            }
            // Hung LA: invalidate this generation so a late callback cannot unlock,
            // clear isAuthenticating so Unlock is not stuck disabled.
            if isAuthenticating {
                authGeneration &+= 1
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
                killOpenOverlay()
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
            killOpenOverlay()
            // Stay in Main after an authenticated erase; next cold launch locks again.
            gate = .unlocked
        }
    }

    /// Flat cream (AGENTS). Retry chrome is a large centered Unlock — no dock.
    /// Face ID sheets hold `.inactive` — keep chrome hidden under the sheet.
    /// When the sheet dismisses (`.active`) while Keychain still applies, show
    /// Unlocking so the gap is not a blank white/cream hang.
    private var showsPostAuthChrome: Bool {
        isAuthenticating && scenePhase == .active
    }

    private var lockScreen: some View {
        ZStack {
            Color.redmedBg.ignoresSafeArea()
            if showUnlockControl || screenCaptured || showsPostAuthChrome {
                lockRetryChrome
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("RedMed is locked")
    }

    /// Status + Unlock after cancel / mismatch (hidden on first Face ID prompt).
    private var lockRetryChrome: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            if screenCaptured {
                Text("Screen sharing is on — use passcode. Profile stays hidden until sharing stops.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.redmedMuted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
            }
            if biometryFailed {
                Text("Couldn't verify it's you. Try again.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.redmedAccent)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
            } else if profileLoadFailed {
                Text("Couldn't load your profile. Try again.")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.redmedAccent)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 28)
            }

            if showUnlockControl || showsPostAuthChrome {
                unlockButton
            }

            Spacer(minLength: 0)
                .frame(maxHeight: 160)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 40)
        .transition(.identity)
    }

    private var unlockButton: some View {
        Button {
            RedMedHaptics.medium()
            startUnlockPipeline(isAuto: false)
        } label: {
            Group {
                if isAuthenticating {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(.white)
                        Text("Unlocking")
                            .font(.system(size: 18, weight: .bold))
                    }
                    .accessibilityLabel("Unlocking with Face ID")
                } else {
                    HStack(spacing: 10) {
                        Image(systemName: "faceid")
                            .font(.system(size: 22, weight: .semibold))
                        Text("Unlock")
                            .font(.system(size: 18, weight: .bold))
                    }
                }
            }
            .foregroundColor(.white)
            .frame(minWidth: 220, minHeight: 56)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 1, green: 0.447, blue: 0.537),
                        Color.redmedAccent
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius, style: .continuous))
            .shadow(color: RedMedChrome.accentShadow, radius: 10, y: 5)
            .contentShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius, style: .continuous))
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
        killOpenOverlay()
        if purge {
            profile.purgeFromMemory()
        }
        SecurePasteboard.clear()
    }

    /// Arm the clip before `gate = .unlocked` so the first Main frame is covered.
    private func beginOpenOverlay() {
        openOverlayOpacity = 1
        playOpenOverlay = LockOpenClip.url != nil
    }

    private func dismissOpenOverlay() {
        withAnimation(.easeOut(duration: 0.18)) {
            openOverlayOpacity = 0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            killOpenOverlay()
        }
    }

    private func killOpenOverlay() {
        playOpenOverlay = false
        openOverlayOpacity = 1
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
                // Entire path is `@MainActor` — LA completion is main-queue but not
                // MainActor-isolated; calling `cancelWarm` / sync adopt outside a
                // Task fails Xcode concurrency checks.
                Task { @MainActor in
                    guard generation == authGeneration else { return }
                    PasserbyWebViewPool.cancelWarm()
                    // Parked Face ID decode: unlock this turn with no Keychain await
                    // (no MainActor yield to WebKit → no blank cream after the sheet).
                    if let didLoad = profile.tryPrepareUnlockPrefetchSync() {
                        finishUnlockAfterAuth(
                            generation: generation,
                            didLoad: didLoad,
                            expectsProfile: didLoad ? true : keychainHasProfile
                        )
                        return
                    }
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
        }
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
            // Clip first, then Main + PHI in the same turn — Face ID sheet is already down.
            beginOpenOverlay()
            gate = .unlocked
            profile.commitUnlockProfile()
            biometryFailed = false
            profileLoadFailed = false
            showUnlockControl = false
            RedMedHaptics.heavy()
            RedMedHaptics.success()
            // Warm after paint — never on the auth → Main critical path.
            Task { @MainActor in
                await Task.yield()
                PasserbyWebViewPool.warmEmbedShell()
            }
        } else if !expectsProfile {
            // Fresh install — auth passed; open empty Main (Edit gates Save).
            keychainHasProfile = false
            profile.prepareEmptyUnlockShell()
            beginOpenOverlay()
            gate = .unlocked
            biometryFailed = false
            profileLoadFailed = false
            showUnlockControl = false
            RedMedHaptics.heavy()
            RedMedHaptics.success()
            Task { @MainActor in
                await Task.yield()
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

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
/// Every owner launch is Face ID / passcode before Main: cream + decorative
/// BrandLogo watermark under the system biometrics sheet. No Accept step.
/// Unlock is retry chrome after cancel / mismatch — not part of the first-load
/// surface. Fresh install unlocks into empty tabs after auth; returning owners
/// load Keychain (fail closed on corrupt blob). Auto-prompt once per lock —
/// including cold launch while still `.inactive` (waiting for `.active` was the
/// cream hang: watermark with no sheet). Face ID sheets put the scene
/// `.inactive` — `didAutoPromptThisLock` blocks re-prompt. The watermark is
/// never a control.
///
/// Speed (minus Face ID wall time): Face ID kicks first; Keychain prefetch +
/// tapper.html string warm still start in the same `onAppear` tick and again
/// inside the unlock pipeline (single-flight overlap). Unlock does **not** wait
/// on AES `#d=` or WKWebView create — placeholder `#d=` + `__REDMED_PROFILE`
/// paints RedMed immediately; durable AES and WebView warm start after the
/// first unlock frame.
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
            // Escape hatch: if LA never callbacks, Unlock must still be tappable.
            // Do not flash Unlock under a live Face ID sheet (common at ~1–2s).
            guard gate == .locked else { return }
            let generation = authGeneration
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard gate == .locked, generation == authGeneration else { return }
            if isAuthenticating {
                try? await Task.sleep(nanoseconds: 3_500_000_000)
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

    /// Unlock / error chrome only after the first Face ID attempt ends.
    private var lockScreen: some View {
        ZStack {
            Color.redmedBg.ignoresSafeArea()
            lockWatermark
            if showUnlockControl || screenCaptured {
                lockRetryChrome
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("RedMed is locked")
    }

    /// Decorative BrandLogo — atmosphere only, never a control.
    private var lockWatermark: some View {
        Image("BrandLogo")
            .resizable()
            .scaledToFit()
            .frame(width: RedMedChrome.lockWatermarkSize, height: RedMedChrome.lockWatermarkSize)
            .clipShape(Circle())
            .opacity(RedMedChrome.lockWatermarkOpacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Status + Unlock after cancel / mismatch (hidden on first Face ID prompt).
    private var lockRetryChrome: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 16) {
                if screenCaptured {
                    Text("Screen sharing is on — unlock with passcode. Profile stays hidden on the share until you stop sharing.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                if biometryFailed {
                    Text("Couldn't verify it's you. Try again.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                } else if profileLoadFailed {
                    Text("Couldn't load your profile. Try again.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                if showUnlockControl {
                    unlockButton
                }
            }
            Spacer(minLength: 0)
                .frame(maxHeight: 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 48)
    }

    private var unlockButton: some View {
        Button {
            RedMedHaptics.medium()
            startUnlockPipeline(isAuto: false)
        } label: {
            Group {
                if isAuthenticating {
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text("Unlocking")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .accessibilityLabel("Unlocking with Face ID")
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Unlock")
                            .font(.system(size: 15, weight: .bold))
                    }
                }
            }
            .foregroundColor(.white)
            .frame(minWidth: 148, minHeight: 44)
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(
                LinearGradient(
                    colors: [Color(red: 1, green: 0.447, blue: 0.537), .redmedAccent],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius))
            .shadow(color: RedMedChrome.accentShadow, radius: 8, y: 4)
        }
        .buttonStyle(RedMedPressStyle(haptic: nil))
        .disabled(isAuthenticating)
        .fixedSize()
        .accessibilityHint("Face ID, Touch ID, or passcode")
    }

    private func tryAutoUnlockIfActive() {
        guard gate == .locked, !didAutoPromptThisLock else { return }
        // Cold launch often starts `.inactive` before first `.active`. Waiting for
        // `.active` left a cream watermark hang with no Face ID. Kick LA unless
        // truly backgrounded — `didAutoPromptThisLock` blocks re-prompt while the
        // Face ID sheet holds the scene `.inactive` (AGENTS: no re-prompt on inactive).
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
    /// attempt is auto Face ID only.
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
        // HTML string during Face ID; WKWebView warm after a short delay so LA presents first.
        Task.detached(priority: .userInitiated) {
            PasserbyHTMLCardView.warmShellCache()
            try? await Task.sleep(nanoseconds: 280_000_000)
            await MainActor.run {
                PasserbyWebViewPool.warmEmbedShell()
            }
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
            reason: "Unlock RedMed with Face ID, Touch ID, or passcode."
        ) { outcome in
            guard generation == authGeneration else { return }
            switch outcome {
            case .declined:
                // Cancel / dismiss — stay locked; Unlock appears for retry.
                isAuthenticating = false
                biometryFailed = false
                showUnlockControl = true
                gate = .locked
                profile.discardUnlockPrefetch()
            case .notInteractive:
                // Cold-start evaluate before the window can present — do not leave
                // Unlock chrome up; clear auto-prompt so `.active` retries once.
                // User cancel is `.declined` (Unlock stays); this is not cancel.
                // Never auto-kick inline when already `.active` — LA can still return
                // appNotInteractive briefly and that looped Face ID forever.
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
                profile.discardUnlockPrefetch()
                VaultHistoryStore.shared.record(.unlockFailed, detail: "appLock")
            case .success:
                // Apply only if this generation is still current. Check again after
                // await — background can bump authGeneration and purge mid-apply.
                Task { @MainActor in
                    guard generation == authGeneration else { return }
                    // Kick WKWebView warm NOW — overlaps Keychain/JSON await so RedMed
                    // can takeEmbed() instead of a cold 84KB parse after unlock.
                    PasserbyWebViewPool.warmEmbedShell()
                    // Off-main SecItem overlaps Keychain apply when the gate still says empty.
                    async let expectsProfileTask = keychainHasProfile
                        ? true
                        : await Task.detached(priority: .userInitiated) {
                            ProfileData.hasStoredProfile()
                        }.value
                    // Keychain + embed JSON only — do not await WKWebView warm or AES.
                    // Staging only: PHI fields stay empty until gate unlocks so
                    // PrivacySnapshotGuard never covers the watermark under capture.
                    let didLoad = await profile.prepareUnlockPrefetchOrReload()
                    let expectsProfile = didLoad ? true : await expectsProfileTask
                    guard generation == authGeneration else {
                        // Late success after background lock — drop staging, no PHI published.
                        profile.discardUnlockPrefetch()
                        profile.purgeFromMemory()
                        return
                    }
                    isAuthenticating = false
                    if didLoad {
                        keychainHasProfile = true
                        RedMedHaptics.success()
                        // Unlock shell first, then publish PHI in the same turn.
                        gate = .unlocked
                        profile.commitUnlockProfile()
                        biometryFailed = false
                        profileLoadFailed = false
                        showUnlockControl = false
                    } else if !expectsProfile {
                        // Fresh install — auth passed; open empty Main (Edit gates Save).
                        keychainHasProfile = false
                        profile.prepareEmptyUnlockShell()
                        RedMedHaptics.success()
                        gate = .unlocked
                        biometryFailed = false
                        profileLoadFailed = false
                        showUnlockControl = false
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
        }
    }
}

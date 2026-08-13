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
/// Cold launch never touches Keychain on the first frame. A UserDefaults gate
/// (set on persist / Keychain presence check) picks lock vs tabs immediately;
/// SecItem still confirms off-main and can correct a stale gate.
///
/// Returning-owner first load is Face ID only: cream + decorative BrandLogo
/// watermark under the system biometrics sheet. No Accept step. Unlock is
/// retry chrome after cancel / mismatch — not part of the first-load surface.
/// Auto-prompt once per lock while `.active` (and again after `.background`).
/// Face ID sheets put the scene `.inactive` — that must not re-prompt. The
/// watermark is never a control.
///
/// Speed (minus Face ID wall time): Keychain decode + AES `#d=` pack + tapper.html
/// shell warm overlap Face ID; unlock applies the prefetched blob/payload with no
/// transition animation so tabs paint on the next frame with a ready shell.
struct OwnerAppLock<Content: View>: View {
    @EnvironmentObject private var profile: ProfileData
    @Environment(\.scenePhase) private var scenePhase
    @ViewBuilder var content: () -> Content

    private enum Gate {
        case locked
        case unlocked
    }

    /// Lock UI on first frame when a prior save set the gate — no cream-only stall
    /// waiting on SecItem. Fresh installs open tabs immediately (empty profile).
    @State private var gate: Gate = ProfileData.prefersLockOnLaunch ? .locked : .unlocked
    @State private var isAuthenticating = false
    /// True only after Face ID / Touch ID (or passcode) mismatch — never on cancel
    /// or cold launch, and never for Keychain decode failure.
    @State private var biometryFailed = false
    @State private var profileLoadFailed = false
    @State private var hasEverHadSensitiveData = ProfileData.prefersLockOnLaunch
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
            tryAutoUnlockIfActive()
            if gate == .unlocked {
                CrashMotionGuard.shared.startMonitoring()
            }
        }
        .task(id: authGeneration) {
            // Escape hatch: if LA never callbacks, Unlock must still appear.
            guard gate == .locked else { return }
            let generation = authGeneration
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard gate == .locked, generation == authGeneration else { return }
            showUnlockControl = true
        }
        .task {
            // First SwiftUI frame already committed — Keychain presence can wait.
            let hasProfile = await Task.detached(priority: .userInitiated) {
                ProfileData.hasStoredProfile()
            }.value
            ProfileData.setStoredProfileGate(hasProfile)
            hasEverHadSensitiveData = hasProfile
            if hasProfile {
                if gate != .locked {
                    // Stale gate said unlocked — lock now. Do not poke an in-flight Face ID.
                    biometryFailed = false
                    profileLoadFailed = false
                    didAutoPromptThisLock = false
                    showUnlockControl = false
                    gate = .locked
                }
                tryAutoUnlockIfActive()
            } else {
                profile.discardUnlockPrefetch()
                showUnlockControl = false
                gate = .unlocked
                CrashMotionGuard.shared.startMonitoring()
            }
        }
        .onChange(of: gate) { _, newGate in
            if newGate == .locked {
                didAutoPromptThisLock = false
                showUnlockControl = false
                tryAutoUnlockIfActive()
            } else {
                // Fresh install / Face ID success — motion after PHI tabs own the CPU.
                CrashMotionGuard.shared.startMonitoring()
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
            biometryFailed = false
            profileLoadFailed = false
            isAuthenticating = false
            didAutoPromptThisLock = false
            showUnlockControl = false
            profile.discardUnlockPrefetch()
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
        guard gate == .locked, scenePhase == .active, !didAutoPromptThisLock else { return }
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

    /// Face ID + overlapped Keychain decode + AES `#d=` pack + shell warm.
    /// Enter path for returning owners — first attempt is auto Face ID only.
    private func startUnlockPipeline(isAuto: Bool) {
        guard gate == .locked else { return }
        if isAuto {
            didAutoPromptThisLock = true
            // First-load surface stays biometrics-only until this attempt ends.
            showUnlockControl = false
        }
        profile.beginUnlockPrefetch()
        // nonisolated cache — safe from any thread / Task.detached.
        PasserbyHTMLCardView.warmShellCache()
        // MainActor: pre-create WKWebView + parse tapper.html while Face ID is up.
        Task { @MainActor in
            PasserbyHTMLCardView.warmShellCache()
            PasserbyWebViewPool.warmEmbedShell()
        }
        unlockWithFaceID()
    }

    private func unlockWithFaceID() {
        guard gate == .locked, !isAuthenticating else { return }
        isAuthenticating = true
        biometryFailed = false
        profileLoadFailed = false
        authGeneration &+= 1
        let generation = authGeneration
        // Warm tapper.html while Face ID is up — unlock must not wait on disk after success.
        Task.detached(priority: .utility) {
            PasserbyHTMLCardView.warmShellCache()
        }
        Task { @MainActor in
            PasserbyWebViewPool.warmEmbedShell()
        }
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
                    let loaded = await profile.applyUnlockPrefetchOrReload()
                    guard generation == authGeneration else {
                        // Late success after background lock — drop any applied PHI.
                        profile.purgeFromMemory()
                        return
                    }
                    // Belt-and-suspenders — usually already warm from startUnlockPipeline.
                    PasserbyHTMLCardView.warmShellCache()
                    PasserbyWebViewPool.warmEmbedShell()
                    isAuthenticating = false
                    if loaded {
                        RedMedHaptics.success()
                        // No soft fade — tabs must appear immediately after Face ID.
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

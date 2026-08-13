import SwiftUI

/// Owner app lock — Face ID / passcode before PHI is held in memory.
///
/// On background / lock: profile fields are purged from RAM (Keychain untouched).
/// On unlock: reload from Keychain. Scanner / passerby shells never mount this —
/// they use `ProfileData(persisting: false)` snapshots only.
///
/// Cold launch never touches Keychain on the first frame. A UserDefaults gate
/// (set on persist / Keychain presence check) picks lock vs tabs immediately;
/// SecItem still confirms off-main and can correct a stale gate.
///
/// One lock screen: BrandLogo watermark + Face ID. No Accept step. Biometrics
/// auto-prompt once per lock while `.active` (and again after `.background`).
/// Cancel / mismatch stays on the watermark; tap to retry. Face ID sheets put
/// the scene `.inactive` — that must not re-prompt.
///
/// Speed (minus Face ID wall time): Keychain decode + tapper.html shell warm
/// overlap Face ID; unlock applies the prefetched blob with no transition
/// animation so tabs paint on the next frame.
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
                    gate = .locked
                }
                tryAutoUnlockIfActive()
            } else {
                profile.discardUnlockPrefetch()
                gate = .unlocked
            }
        }
        .onChange(of: gate) { _, newGate in
            if newGate == .locked {
                didAutoPromptThisLock = false
                tryAutoUnlockIfActive()
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
            profile.discardUnlockPrefetch()
            gate = .unlocked
        }
    }

    private var lockScreen: some View {
        ZStack {
            // Flat cream — matches UILaunchScreen; skip page gradient on the critical path.
            Color.redmedBg.ignoresSafeArea()

            // Single composition: watermark BrandLogo only — Face ID is the enter path.
            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: RedMedChrome.lockWatermarkSize, height: RedMedChrome.lockWatermarkSize)
                .clipShape(Circle())
                .opacity(RedMedChrome.lockWatermarkOpacity)
                .accessibilityHidden(true)

            VStack(spacing: 14) {
                Spacer(minLength: 48)
                if screenCaptured {
                    Text("Screen sharing is on — unlock with passcode. Profile stays hidden on the share until you stop sharing.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                if biometryFailed {
                    Text("Couldn't verify it's you. Tap to try again.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                } else if profileLoadFailed {
                    Text("Couldn't load your profile. Tap to try again.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                }
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isAuthenticating else { return }
            RedMedHaptics.medium()
            startUnlockPipeline(isAuto: false)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("RedMed is locked")
        .accessibilityHint("Unlocks with Face ID, Touch ID, or passcode")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            startUnlockPipeline(isAuto: false)
        }
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
        if purge {
            profile.purgeFromMemory()
        }
        SecurePasteboard.clear()
    }

    /// Face ID + overlapped Keychain decode + shell warm. Enter path for returning owners.
    private func startUnlockPipeline(isAuto: Bool) {
        guard gate == .locked else { return }
        if isAuto {
            didAutoPromptThisLock = true
        }
        profile.beginUnlockPrefetch()
        PasserbyHTMLShell.warmShellCache()
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
        BiometricAuth.authenticate(
            reason: "Unlock RedMed with Face ID, Touch ID, or passcode."
        ) { outcome in
            guard generation == authGeneration else { return }
            switch outcome {
            case .declined:
                // Cancel / dismiss — stay locked, no “couldn't verify” banner.
                isAuthenticating = false
                biometryFailed = false
                gate = .locked
                profile.discardUnlockPrefetch()
            case .notVerified:
                // Face ID / Touch ID (or passcode) did not match.
                RedMedHaptics.error()
                isAuthenticating = false
                biometryFailed = true
                gate = .locked
                profile.discardUnlockPrefetch()
                VaultHistoryStore.shared.record(.unlockFailed, detail: "appLock")
            case .success:
                // Prefetch usually finished during Face ID — apply and show tabs next frame.
                Task { @MainActor in
                    let loaded = await profile.applyUnlockPrefetchOrReload()
                    PasserbyHTMLCardView.warmShellCache()
                    guard generation == authGeneration else { return }
                    isAuthenticating = false
                    if loaded {
                        RedMedHaptics.success()
                        // No soft animation — unlock must not spend frames on a fade.
                        gate = .unlocked
                        biometryFailed = false
                        profileLoadFailed = false
                    } else {
                        // Corrupt / unreadable Keychain — stay locked; do not open empty Edit.
                        RedMedHaptics.error()
                        gate = .locked
                        biometryFailed = false
                        profileLoadFailed = true
                    }
                }
            }
        }
    }
}

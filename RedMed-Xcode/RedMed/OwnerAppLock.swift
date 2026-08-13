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
/// auto-prompt when the lock shell appears (and again when returning from
/// `.background`). Cancel / mismatch stays on the same watermark; tap to retry.
/// Face ID sheets put the scene `.inactive` — do not treat that as a fresh open.
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
        }
        .task {
            // First SwiftUI frame already committed — Keychain can wait.
            let hasProfile = await Task.detached(priority: .userInitiated) {
                ProfileData.hasStoredProfile()
            }.value
            ProfileData.setStoredProfileGate(hasProfile)
            hasEverHadSensitiveData = hasProfile
            if hasProfile {
                // Fresh lock UI every cold load — no stale “couldn't verify” banner.
                biometryFailed = false
                profileLoadFailed = false
                gate = .locked
            } else {
                gate = .unlocked
            }
        }
        .onChange(of: scenePhase) { prior, phase in
            // LAContext / system auth sheets put the scene `.inactive`.
            // Only purge + lock on true background (same rule as VaultHistoryView).
            if phase == .background,
               profile.hasSensitiveProfileData
                || hasEverHadSensitiveData
                || profile.holdsEditingSession {
                lock(purge: true)
            } else if phase == .active, prior == .background, gate == .locked {
                // Returning to the app — Face ID again. Do not re-prompt after
                // `.inactive` (that is the Face ID sheet itself).
                unlockWithFaceID()
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
            gate = .unlocked
        }
    }

    private var lockScreen: some View {
        ZStack {
            RedMedPageBackground()

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
                if isAuthenticating {
                    ProgressView()
                        .tint(.redmedAccent)
                        .accessibilityLabel("Unlocking with Face ID")
                }
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
                } else if !isAuthenticating {
                    Text("Tap to unlock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedMuted)
                }
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isAuthenticating else { return }
            RedMedHaptics.medium()
            unlockWithFaceID()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("RedMed is locked")
        .accessibilityHint("Unlocks with Face ID, Touch ID, or passcode")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            unlockWithFaceID()
        }
        .onAppear {
            unlockWithFaceID()
        }
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

    /// Face ID / passcode is the only enter path for a returning owner.
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
                // Cancel / dismiss — stay locked, no “couldn't verify” banner.
                isAuthenticating = false
                biometryFailed = false
                gate = .locked
            case .notVerified:
                // Face ID / Touch ID (or passcode) did not match.
                RedMedHaptics.error()
                isAuthenticating = false
                biometryFailed = true
                gate = .locked
                VaultHistoryStore.shared.record(.unlockFailed, detail: "appLock")
            case .success:
                // Decode off the main thread — unlock UI stays on watermark until apply.
                Task {
                    let loaded = await profile.reloadFromKeychainAsync()
                    guard generation == authGeneration else { return }
                    isAuthenticating = false
                    if loaded {
                        RedMedHaptics.success()
                        withAnimation(RedMedMotion.soft) {
                            gate = .unlocked
                        }
                        biometryFailed = false
                        profileLoadFailed = false
                    } else {
                        // Corrupt / unreadable Keychain — stay locked; do not open empty Edit.
                        // Not a biometry failure — different copy.
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

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
        .onChange(of: scenePhase) { _, phase in
            // LAContext / system auth sheets put the scene `.inactive`.
            // Only purge + lock on true background (same rule as VaultHistoryView).
            if phase == .background,
               profile.hasSensitiveProfileData
                || hasEverHadSensitiveData
                || profile.holdsEditingSession {
                lock(purge: true)
            }
        }
        .onChange(of: profile.hasSensitiveProfileData) { _, hasData in
            if hasData { hasEverHadSensitiveData = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            screenCaptured = UIScreen.main.isCaptured
        }
    }

    private var lockScreen: some View {
        ZStack {
            RedMedPageBackground()
            VStack(spacing: 18) {
                Spacer(minLength: 48)
                Image("BrandLogo")
                    .resizable()
                    .frame(width: RedMedChrome.logoSize, height: RedMedChrome.logoSize)
                    .clipShape(Circle())
                    .shadow(color: RedMedChrome.accentShadow, radius: 14, y: 6)
                Text("RedMed")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.redmedDark)
                    .kerning(-0.4)
                Image(systemName: "lock.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.redmedAccent)
                    .padding(.top, 2)
                    .accessibilityLabel("RedMed is locked")
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
                } else if profileLoadFailed {
                    Text("Couldn't load your profile. Try again.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                }
                Button {
                    RedMedHaptics.medium()
                    acceptThenUnlock()
                } label: {
                    Group {
                        if isAuthenticating {
                            ProgressView().tint(.white)
                        } else {
                            Text("Accept")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 1, green: 0.447, blue: 0.537), .redmedAccent],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius))
                    .shadow(color: RedMedChrome.accentShadow, radius: 10, y: 5)
                }
                .buttonStyle(RedMedPressStyle(haptic: nil))
                .disabled(isAuthenticating)
                .padding(.horizontal, 28)
                .padding(.top, 8)
                Spacer()
            }
        }
        // Biometrics never run until Accept — no onAppear / scenePhase auto-prompt.
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

    /// Accept is the only entry into LocalAuthentication for app unlock.
    private func acceptThenUnlock() {
        guard gate == .locked, !isAuthenticating else { return }
        isAuthenticating = true
        biometryFailed = false
        profileLoadFailed = false
        authGeneration &+= 1
        let generation = authGeneration
        BiometricAuth.authenticate(
            reason: "Confirm with Face ID, Touch ID, or passcode after Accept to unlock your RedMed profile."
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
            case .success:
                // Decode off the main thread — unlock UI stays on cream lock until apply.
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

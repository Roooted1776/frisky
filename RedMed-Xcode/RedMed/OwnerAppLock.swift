import SwiftUI

/// Owner app lock — Face ID / passcode before PHI is held in memory.
///
/// On background / lock: profile fields are purged from RAM (Keychain untouched).
/// On unlock: reload from Keychain. Scanner / passerby shells never mount this —
/// they use `ProfileData(persisting: false)` snapshots only.
///
/// Cold launch never touches Keychain on the first frame — a cream shell paints
/// instantly, then an off-main presence check decides lock vs tabs.
struct OwnerAppLock<Content: View>: View {
    @EnvironmentObject private var profile: ProfileData
    @Environment(\.scenePhase) private var scenePhase
    @ViewBuilder var content: () -> Content

    private enum Gate {
        /// First paint — cream shell, zero Keychain / Face ID.
        case painting
        case locked
        case unlocked
    }

    @State private var gate: Gate = .painting
    @State private var isAuthenticating = false
    /// True only after Face ID / Touch ID (or passcode) mismatch — never on cancel
    /// or cold launch, and never for Keychain decode failure.
    @State private var biometryFailed = false
    @State private var profileLoadFailed = false
    @State private var hasEverHadSensitiveData = false
    /// Bumps on lock so a late Face ID success cannot unlock after background.
    @State private var authGeneration = 0
    /// Default false — read capture state after first paint (see onAppear).
    @State private var screenCaptured = false

    var body: some View {
        ZStack {
            switch gate {
            case .painting:
                coldLaunchShell
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

    /// Matches launch screen / redmedBg so the post-splash gap is never black.
    private var coldLaunchShell: some View {
        ZStack {
            Color.redmedBg.ignoresSafeArea()
            Image("BrandLogo")
                .resizable()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityHidden(true)
    }

    private var lockScreen: some View {
        ZStack {
            Color.redmedBg.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer(minLength: 40)
                Image("BrandLogo")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Image(systemName: "lock.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.redmedAccent)
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
                    acceptThenUnlock()
                } label: {
                    Group {
                        if isAuthenticating {
                            ProgressView().tint(.white)
                        } else {
                            Text("Accept")
                                .font(.system(size: 15, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.redmedAccent)
                    .clipShape(Capsule())
                }
                .disabled(isAuthenticating)
                .padding(.horizontal, 24)
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
                        gate = .unlocked
                        biometryFailed = false
                        profileLoadFailed = false
                    } else {
                        // Corrupt / unreadable Keychain — stay locked; do not open empty Edit.
                        // Not a biometry failure — different copy.
                        gate = .locked
                        biometryFailed = false
                        profileLoadFailed = true
                    }
                }
            }
        }
    }
}

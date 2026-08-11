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
    @State private var failed = false
    @State private var hasEverHadSensitiveData = false
    /// Bumps on lock so a late Face ID success cannot unlock after background.
    @State private var authGeneration = 0

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
        .task {
            // First SwiftUI frame already committed — Keychain can wait.
            let hasProfile = await Task.detached(priority: .userInitiated) {
                ProfileData.hasStoredProfile()
            }.value
            hasEverHadSensitiveData = hasProfile
            if hasProfile {
                gate = .locked
            } else {
                gate = .unlocked
            }
        }
        .onChange(of: scenePhase) { _, phase in
            // LAContext / system auth sheets put the scene `.inactive`.
            // Only purge + lock on true background (same rule as VaultHistoryView).
            if phase == .background, profile.hasSensitiveProfileData || hasEverHadSensitiveData {
                lock(purge: true)
            }
        }
        .onChange(of: profile.hasSensitiveProfileData) { _, hasData in
            if hasData { hasEverHadSensitiveData = true }
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
                Text("RedMed is locked")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.redmedDark)
                Text("Face ID first. Passcode if Face ID fails or is locked out. Profile is wiped from RAM while locked — Keychain stays on-device. Local only, forever.")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
                if failed {
                    Text("Couldn't verify it's you. Try again.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                }
                Spacer()
                Button {
                    unlock()
                } label: {
                    Group {
                        if isAuthenticating {
                            ProgressView().tint(.white)
                        } else {
                            Text("Unlock with Face ID")
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
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            if !isAuthenticating { unlock() }
        }
    }

    private func lock(purge: Bool) {
        authGeneration &+= 1
        gate = .locked
        isAuthenticating = false
        failed = false
        if purge {
            profile.purgeFromMemory()
        }
        SecurePasteboard.clear()
    }

    private func unlock() {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        failed = false
        authGeneration &+= 1
        let generation = authGeneration
        BiometricAuth.authenticate(
            reason: "Unlock RedMed to show your on-device emergency profile."
        ) { success in
            guard generation == authGeneration else { return }
            if !success {
                isAuthenticating = false
                failed = true
                gate = .locked
                return
            }
            // Decode off the main thread — unlock UI stays on cream lock until apply.
            Task {
                _ = await profile.reloadFromKeychainAsync()
                guard generation == authGeneration else { return }
                isAuthenticating = false
                gate = .unlocked
                failed = false
            }
        }
    }
}

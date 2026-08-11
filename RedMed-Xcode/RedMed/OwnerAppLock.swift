import SwiftUI

/// Owner app lock — Face ID / passcode before PHI is held in memory.
///
/// On background / lock: profile fields are purged from RAM (Keychain untouched).
/// On unlock: reload from Keychain. Scanner / passerby shells never mount this —
/// they use `ProfileData(persisting: false)` snapshots only.
struct OwnerAppLock<Content: View>: View {
    @EnvironmentObject private var profile: ProfileData
    @Environment(\.scenePhase) private var scenePhase
    @ViewBuilder var content: () -> Content

    private enum Gate {
        case resolving
        case locked
        case unlocked
    }

    @State private var gate: Gate = .resolving
    @State private var isAuthenticating = false
    @State private var failed = false
    @State private var hasEverHadSensitiveData = false

    var body: some View {
        ZStack {
            switch gate {
            case .resolving:
                Color.redmedBg.ignoresSafeArea()
            case .unlocked:
                content()
            case .locked:
                lockScreen
            }
        }
        .onAppear { resolveInitialGate() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, profile.hasSensitiveProfileData || hasEverHadSensitiveData {
                lock(purge: true)
            }
        }
        .onChange(of: profile.hasSensitiveProfileData) { _, hasData in
            if hasData { hasEverHadSensitiveData = true }
        }
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

    private func resolveInitialGate() {
        if profile.hasSensitiveProfileData {
            hasEverHadSensitiveData = true
            lock(purge: true)
        } else {
            gate = .unlocked
        }
    }

    private func lock(purge: Bool) {
        gate = .locked
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
        BiometricAuth.authenticate(
            reason: "Unlock RedMed to show your on-device emergency profile."
        ) { success in
            isAuthenticating = false
            if success {
                _ = profile.reloadFromKeychain()
                gate = .unlocked
                failed = false
            } else {
                failed = true
                gate = .locked
            }
        }
    }
}

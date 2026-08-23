import SwiftUI

/// Owner app lock — Face ID / Touch ID before PHI is published into profile fields.
/// No passcode / password pad on this gate (tapper / Main are next).
///
/// Keychain profile is biometry-bound (`KeychainStore`); Face ID parks an
/// `LAContext` so SecItem can read without a second sheet. Background clears
/// the park. Prefetch without context only resolves legacy unbound blobs.
///
/// **Warm rules:** `PasserbyHTMLCardView.warmShellCache()` (string) may overlap
/// Face ID. `PasserbyWebViewPool.warmEmbedShell()` (WK) runs **only after**
/// `gate = .unlocked` — WebKit during Face ID steals MainActor and leaves a
/// cream hang after auth.
struct OwnerAppLock<Content: View>: View {
    @EnvironmentObject private var profile: ProfileData
    @Environment(\.scenePhase) private var scenePhase
    @ViewBuilder var content: () -> Content

    private enum Gate {
        case locked
        case unlocked
    }

    @State private var gate: Gate = .locked
    @State private var isAuthenticating = false
    @State private var biometryFailed = false
    @State private var profileLoadFailed = false
    @State private var keychainHasProfile = ProfileData.prefersLockOnLaunch
    @State private var authGeneration = 0
    @State private var screenCaptured = false
    @State private var didAutoPromptThisLock = false
    @State private var showUnlockControl = false

    var body: some View {
        ZStack {
            switch gate {
            case .unlocked:
                content()
            case .locked:
                if showUnlockControl {
                    FacePage(
                        screenCaptured: screenCaptured,
                        biometryFailed: biometryFailed,
                        profileLoadFailed: profileLoadFailed,
                        isAuthenticating: isAuthenticating,
                        onProceed: { startUnlockPipeline(isAuto: false) }
                    )
                } else {
                    LockEntryPage()
                }
            }
        }
        .transaction { $0.animation = nil }
        .onAppear {
            screenCaptured = UIScreen.main.isCaptured
            tryAutoUnlockIfActive()
            profile.beginUnlockPrefetch()
            // String cache only — not WK — during Face ID window.
            Task.detached(priority: .userInitiated) {
                PasserbyHTMLCardView.warmShellCache()
            }
        }
        .task(id: authGeneration) {
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
            let hasProfile = await Task.detached(priority: .userInitiated) {
                ProfileData.hasStoredProfile()
            }.value
            ProfileData.setStoredProfileGate(hasProfile)
            keychainHasProfile = hasProfile
            if hasProfile {
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
                BiometricAuth.clearAuthenticationContext()
                tryAutoUnlockIfActive()
            } else {
                Task { @MainActor in
                    await Task.yield()
                    CrashMotionGuard.shared.startMonitoring()
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                SecurePasteboard.clear()
                // Drop SecItem auth session — next read needs Face ID again.
                BiometricAuth.clearAuthenticationContext()
                if gate == .locked {
                    profile.discardUnlockPrefetch()
                    PasserbyWebViewPool.cancelWarm()
                }
            } else if phase == .active, gate == .locked {
                tryAutoUnlockIfActive()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            screenCaptured = UIScreen.main.isCaptured
        }
        .onReceive(NotificationCenter.default.publisher(for: .redMedDidEraseLocalData)) { _ in
            keychainHasProfile = false
            biometryFailed = false
            profileLoadFailed = false
            isAuthenticating = false
            didAutoPromptThisLock = false
            showUnlockControl = false
            profile.discardUnlockPrefetch()
            BiometricAuth.clearAuthenticationContext()
            gate = .unlocked
        }
    }

    private func tryAutoUnlockIfActive() {
        guard gate == .locked, !didAutoPromptThisLock, !showUnlockControl else { return }
        guard scenePhase != .background else { return }
        didAutoPromptThisLock = true
        startUnlockPipeline(isAuto: true)
    }

    private func startUnlockPipeline(isAuto: Bool) {
        guard gate == .locked else { return }
        if isAuto {
            didAutoPromptThisLock = true
            showUnlockControl = false
        }
        unlockWithFaceID()
        profile.beginUnlockPrefetch()
        // String warm only during Face ID — WK waits until after unlock.
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
            reason: "Unlock RedMed",
            allowPasscode: false
        ) { outcome in
            Task { @MainActor in
                guard generation == authGeneration else { return }
                switch outcome {
                case .declined:
                    isAuthenticating = false
                    biometryFailed = false
                    showUnlockControl = true
                    gate = .locked
                case .notInteractive:
                    isAuthenticating = false
                    biometryFailed = false
                    profileLoadFailed = false
                    gate = .locked
                    didAutoPromptThisLock = false
                    showUnlockControl = false
                case .notVerified:
                    RedMedHaptics.error()
                    isAuthenticating = false
                    biometryFailed = true
                    showUnlockControl = true
                    gate = .locked
                    VaultHistoryStore.shared.record(.unlockFailed, detail: "appLock")
                case .success:
                    await Task.yield()
                    guard generation == authGeneration else { return }
                    // Context is parked — bound Keychain load works in prepareUnlock.
                    profile.beginUnlockPrefetch()
                    await applyUnlockSuccess(generation: generation)
                }
            }
        }
    }

    @MainActor
    private func applyUnlockSuccess(generation: Int) async {
        guard generation == authGeneration else { return }
        if tryFinishWithParkedUnlock(generation: generation) { return }
        async let expectsProfileTask = keychainHasProfile
            ? true
            : await Task.detached(priority: .userInitiated) {
                ProfileData.hasStoredProfile()
            }.value
        let didLoad = await profile.prepareUnlockPrefetchOrReload()
        let expectsProfile = didLoad ? true : await expectsProfileTask
        finishUnlockAfterAuth(
            generation: generation,
            didLoad: didLoad,
            expectsProfile: expectsProfile
        )
    }

    @MainActor
    private func tryFinishWithParkedUnlock(generation: Int) -> Bool {
        PasserbyWebViewPool.cancelWarm()
        guard let didLoad = profile.tryPrepareUnlockPrefetchSync() else {
            return false
        }
        if !didLoad, !keychainHasProfile { return false }
        // Bound item may have parked empty before LAContext existed — do not fail closed.
        if !didLoad, keychainHasProfile { return false }
        finishUnlockAfterAuth(
            generation: generation,
            didLoad: didLoad,
            expectsProfile: didLoad ? true : keychainHasProfile
        )
        return true
    }

    @MainActor
    private func finishUnlockAfterAuth(
        generation: Int,
        didLoad: Bool,
        expectsProfile: Bool
    ) {
        guard generation == authGeneration else {
            profile.discardUnlockPrefetch()
            profile.purgeFromMemory()
            BiometricAuth.clearAuthenticationContext()
            return
        }
        isAuthenticating = false
        if didLoad {
            keychainHasProfile = true
            gate = .unlocked
            profile.commitUnlockProfile()
            biometryFailed = false
            profileLoadFailed = false
            showUnlockControl = false
            // WK warm only after unlock — never during Face ID.
            Task(priority: .utility) { @MainActor in
                RedMedHaptics.success()
                PasserbyWebViewPool.warmEmbedShell()
            }
        } else if !expectsProfile {
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
            RedMedHaptics.error()
            gate = .locked
            biometryFailed = false
            profileLoadFailed = true
            showUnlockControl = true
            BiometricAuth.clearAuthenticationContext()
        }
    }
}

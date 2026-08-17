import SwiftUI
import UIKit

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
/// Every owner launch is Face ID / passcode before Main: cream + muted
/// `LockOpen` atmosphere video behind a Face ID–sized medical mark (`FaceIDFrame`
/// clip, else `LockMedGlyph` — not BrandLogo, not Apple Face ID scan). Path:
/// open → auth → Main. Video never gates Face ID or Main — missing file /
/// Reduce Motion / Low Power = cream + static glyph. No Accept step. No
/// post-auth overlay (that clip-over-Main was the cream hang). Bottom ~25%
/// cream dock: **Proceed** only (Face ID retry). Dock is retry chrome after
/// cancel / mismatch; hidden on the first Face ID prompt.
/// Fresh install unlocks into empty tabs after auth; returning owners load
/// Keychain (fail closed on corrupt blob). Auto-prompt once per lock on the
/// first **interactive** frame (UIKit active / scene `.active`) — not cold
/// `.inactive`. Evaluating LA while inactive presents a SpringBoard overlay;
/// after Face ID the owner had to tap the app again to open Main.
/// `didAutoPromptThisLock` still blocks re-prompt while the Face ID sheet holds
/// `.inactive`. App lock reuses a just-completed device Face ID (short window)
/// so that scan opens Main; Edit / NFC / vault stay reuse-zero.
///
/// Speed (minus Face ID wall time): Face ID kicks on first interactive frame;
/// Keychain prefetch + tapper.html string warm start in the same `onAppear`
/// tick and again inside the unlock pipeline (single-flight). Parked Keychain
/// adopt unlocks on the LA main-queue turn via `MainActor.assumeIsolated` (no
/// Task hop). Unlock dock is solid cream (no material blur). Haptic + WKWebView
/// warm run at utility priority after `gate = .unlocked` so Main paints first.
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
    /// Face ID succeeded while the sheet still held `.inactive` — apply when
    /// the scene is interactive so Main paints without an extra tap.
    @State private var pendingUnlockGeneration: Int? = nil

    var body: some View {
        ZStack {
            switch gate {
            case .unlocked:
                content()
            case .locked:
                lockScreen
            }
        }
        // Instant lock ↔ Main — no soft fade (reads as lag / stuck cream).
        .transaction { $0.animation = nil }
        .onAppear {
            screenCaptured = UIScreen.main.isCaptured
            // Prefetch now; Face ID waits until the window can present in-app.
            tryAutoUnlockIfActive()
            flushPendingUnlock()
            // Always prefetch (single-flight). Do not gate on UserDefaults — stale/false
            // gate left Face ID overlapping nothing.
            profile.beginUnlockPrefetch()
            Task.detached(priority: .userInitiated) {
                PasserbyHTMLCardView.warmShellCache()
            }
        }
        .task(id: authGeneration) {
            // Hung LA only — do not flash Proceed under a live Face ID sheet.
            // Path is open → auth → Main; Proceed is cancel / mismatch / dead LA.
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
            flushPendingUnlock()
            tryAutoUnlockIfActive()
        }
        .onChange(of: gate) { _, newGate in
            if newGate == .locked {
                didAutoPromptThisLock = false
                showUnlockControl = false
                pendingUnlockGeneration = nil
                tryAutoUnlockIfActive()
            } else {
                pendingUnlockGeneration = nil
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
                flushPendingUnlock()
                tryAutoUnlockIfActive()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // SwiftUI scenePhase can lag UIKit; this is the frame the window can
            // present LA in-app and the frame Main must paint after Face ID.
            flushPendingUnlock()
            tryAutoUnlockIfActive()
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
            pendingUnlockGeneration = nil
            profile.discardUnlockPrefetch()
            // Stay in Main after an authenticated erase; next cold launch locks again.
            gate = .unlocked
        }
    }

    /// Remodeled load shell: cream + muted LockOpen bloom behind the Face ID
    /// frame clip (static glyph fallback). Retry chrome is a ~25% cream dock
    /// with Proceed. Face ID sheets hold `.inactive` — mark only
    /// under the sheet; atmosphere + frame clips keep playing (pause on
    /// `.background` only). After auth success: straight to Main — no clip
    /// overlay, no “Opening” dock.
    private var showsRetryDock: Bool {
        showUnlockControl || screenCaptured
    }

    private var lockScreen: some View {
        GeometryReader { geo in
            ZStack {
                lockAtmosphere

                // Quiet center while Face ID owns the sheet — functional glyph only.
                if !showsRetryDock {
                    lockLoadGlyph
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }

                if showsRetryDock {
                    lockRetryChrome(height: dockHeight(in: geo.size))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("RedMed is locked")
    }

    private func dockHeight(in size: CGSize) -> CGFloat {
        max(size.height * RedMedChrome.unlockDockHeightFraction, RedMedChrome.unlockDockMinHeight)
    }

    /// Cream first paint, then muted LockOpen bloom behind the glyph.
    /// Static washes stay for Reduce Motion / missing clip. Video never waits
    /// Face ID or Main — AV starts on the next run loop; unlock tears it down
    /// without waiting for a frame or end.
    private var lockAtmosphere: some View {
        ZStack {
            Color.redmedBg
            if LockOpenClip.shouldPlay {
                LockAtmosphereVideo(playing: scenePhase != .background)
            } else {
                RadialGradient(
                    colors: [
                        Color.redmedWash.opacity(0.78),
                        Color.redmedWash.opacity(0.22),
                        Color.redmedBg.opacity(0)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.12),
                    startRadius: 12,
                    endRadius: 520
                )
                RadialGradient(
                    colors: [
                        Color.redmedAccent.opacity(0.07),
                        Color.redmedBg.opacity(0)
                    ],
                    center: UnitPoint(x: 0.5, y: 0.92),
                    startRadius: 8,
                    endRadius: 340
                )
                LinearGradient(
                    colors: [
                        Color.redmedSurface.opacity(0.55),
                        Color.clear,
                        Color.redmedWash.opacity(0.18)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Small medical lock mark under the system sheet. Higgs `FaceIDFrame`
    /// clip when present; static glyph otherwise. Video never waits Face ID.
    private var lockLoadGlyph: some View {
        Group {
            if FaceIDFrameClip.shouldPlay {
                FaceIDFrameVideo(playing: scenePhase != .background)
                    .frame(
                        width: RedMedChrome.unlockFrameSize,
                        height: RedMedChrome.unlockFrameSize
                    )
            } else {
                LockMedGlyph()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .offset(y: -28)
        .allowsHitTesting(false)
    }

    /// Proceed after cancel / mismatch (hidden on first Face ID prompt).
    /// Bottom sheet dock: ~25% of the screen, solid cream, continuous corners.
    private func lockRetryChrome(height: CGFloat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: 10) {
                Capsule()
                    .fill(Color.redmedDark.opacity(0.14))
                    .frame(width: 36, height: 4)
                    .padding(.bottom, 2)

                if screenCaptured {
                    Text("Screen sharing is on — unlock with passcode. Profile stays hidden on the share until you stop sharing.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                if biometryFailed {
                    Text("Couldn't verify it's you. Try again.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                } else if profileLoadFailed {
                    Text("Couldn't load your profile. Try again.")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }

                if showUnlockControl {
                    proceedButton
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background { unlockDockBackground }
            .padding(.horizontal, 14)
            .padding(.bottom, 10)
            .frame(height: height)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.identity)
    }

    /// Solid cream dock — no material blur (faster composite under/after Face ID).
    private var unlockDockBackground: some View {
        let shape = RoundedRectangle(cornerRadius: RedMedChrome.unlockDockRadius, style: .continuous)
        return shape
            .fill(Color.redmedSurface)
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.55),
                            Color.redmedDivider
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)
    }

    private var proceedButton: some View {
        Button {
            RedMedHaptics.medium()
            startUnlockPipeline(isAuto: false)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "faceid")
                    .font(.system(size: 18, weight: .semibold))
                Text("Proceed")
                    .font(.system(size: 16, weight: .bold))
            }
            .accessibilityLabel(isAuthenticating ? "Proceeding with Face ID" : "Proceed")
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .padding(.horizontal, 22)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: RedMedChrome.unlockButtonRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1, green: 0.447, blue: 0.537).opacity(0.75),
                                Color.redmedAccent.opacity(0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: RedMedChrome.unlockButtonRadius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.32), lineWidth: 1)
                    }
                    .shadow(color: RedMedChrome.accentShadow, radius: 12, y: 6)
            }
        }
        .buttonStyle(RedMedPressStyle(haptic: nil))
        .disabled(isAuthenticating)
        .accessibilityHint("Face ID, Touch ID, or passcode")
    }

    private func tryAutoUnlockIfActive() {
        guard gate == .locked, !didAutoPromptThisLock else { return }
        // Face ID must present in-app. Evaluating during cold `.inactive` puts
        // the sheet on SpringBoard — after Face ID the owner had to tap the
        // icon again. Cream still paints first; AV / WebKit stay deferred so
        // interactive arrives on the next frame. `didAutoPromptThisLock`
        // blocks re-prompt while the Face ID sheet holds `.inactive`.
        guard canPresentLocalAuthentication else { return }
        didAutoPromptThisLock = true
        startUnlockPipeline(isAuto: true)
    }

    /// Window can present an in-app LA sheet (or reuse just-completed device Face ID).
    private var canPresentLocalAuthentication: Bool {
        if scenePhase == .background { return false }
        if UIApplication.shared.applicationState == .background { return false }
        if UIApplication.shared.applicationState == .active { return true }
        if scenePhase == .active { return true }
        return UIApplication.shared.connectedScenes.contains {
            $0.activationState == .foregroundActive
        }
    }

    /// Apply a Face ID success that landed while the sheet held `.inactive`.
    private func flushPendingUnlock() {
        guard gate == .locked, let generation = pendingUnlockGeneration else { return }
        guard generation == authGeneration else {
            pendingUnlockGeneration = nil
            return
        }
        pendingUnlockGeneration = nil
        applyUnlockSuccess(generation: generation)
    }

    private func lock(purge: Bool) {
        authGeneration &+= 1
        gate = .locked
        isAuthenticating = false
        biometryFailed = false
        profileLoadFailed = false
        showUnlockControl = false
        pendingUnlockGeneration = nil
        if purge {
            profile.purgeFromMemory()
        }
        SecurePasteboard.clear()
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
            reason: "Unlock RedMed",
            allowableReuseDuration: BiometricAuth.appLockReuseDuration
        ) { outcome in
            guard generation == authGeneration else { return }
            switch outcome {
            case .declined:
                // Cancel / dismiss — stay locked; Proceed appears for retry.
                // Keep Keychain prefetch — no PHI published until success; Proceed
                // tap must not cold-decode again (stuck / lag feel).
                pendingUnlockGeneration = nil
                isAuthenticating = false
                biometryFailed = false
                showUnlockControl = true
                gate = .locked
            case .notInteractive:
                // Evaluate before the window can present — do not leave Proceed
                // chrome up; clear auto-prompt so `.active` retries once.
                // User cancel is `.declined` (Proceed stays); this is not cancel.
                // Never auto-kick inline when already interactive — LA can still
                // return notInteractive briefly and that looped Face ID forever.
                pendingUnlockGeneration = nil
                isAuthenticating = false
                biometryFailed = false
                profileLoadFailed = false
                gate = .locked
                didAutoPromptThisLock = false
                if canPresentLocalAuthentication {
                    // Already interactive but LA refused — Unlock, no retry storm.
                    showUnlockControl = true
                } else {
                    // Cold `.inactive` — didBecomeActive / `.active` retries once.
                    showUnlockControl = false
                }
                // Keep prefetch — Face ID will overlap on the active retry / Unlock tap.
            case .notVerified:
                // Face ID / Touch ID (or passcode) did not match.
                RedMedHaptics.error()
                pendingUnlockGeneration = nil
                isAuthenticating = false
                biometryFailed = true
                showUnlockControl = true
                gate = .locked
                // Keep prefetch for fast retry — staging is not published.
                VaultHistoryStore.shared.record(.unlockFailed, detail: "appLock")
            case .success:
                // BiometricAuth already hopped a main turn past Face ID teardown.
                // Apply now; if the sheet still holds `.inactive`, pending flush
                // on didBecomeActive paints Main without tapping the icon.
                pendingUnlockGeneration = generation
                applyUnlockSuccess(generation: generation)
            }
        }
    }

    /// Fast path: parked Face ID decode on the current main turn.
    /// Slow path: `Task { @MainActor }` only when Keychain still needs an await.
    private func applyUnlockSuccess(generation: Int) {
        guard generation == authGeneration, gate == .locked else { return }
        if Thread.isMainThread {
            let parked = MainActor.assumeIsolated {
                tryFinishWithParkedUnlock(generation: generation)
            }
            if parked { return }
        }

        Task { @MainActor in
            guard generation == authGeneration, gate == .locked else { return }
            if tryFinishWithParkedUnlock(generation: generation) { return }
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

    /// Cancel stale WebKit warm + adopt Face ID–parked Keychain if ready.
    /// Returns `true` when unlock finished (hit or empty Keychain result).
    @MainActor
    private func tryFinishWithParkedUnlock(generation: Int) -> Bool {
        PasserbyWebViewPool.cancelWarm()
        guard let didLoad = profile.tryPrepareUnlockPrefetchSync() else {
            return false
        }
        finishUnlockAfterAuth(
            generation: generation,
            didLoad: didLoad,
            expectsProfile: didLoad ? true : keychainHasProfile
        )
        return true
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
            pendingUnlockGeneration = nil
            profile.discardUnlockPrefetch()
            profile.purgeFromMemory()
            return
        }
        isAuthenticating = false
        pendingUnlockGeneration = nil
        if didLoad {
            keychainHasProfile = true
            // Unlock shell first, then publish PHI in the same turn.
            gate = .unlocked
            profile.commitUnlockProfile()
            biometryFailed = false
            profileLoadFailed = false
            showUnlockControl = false
            // Haptic + WebKit off the critical path — Main paints first.
            Task(priority: .utility) { @MainActor in
                RedMedHaptics.success()
                PasserbyWebViewPool.warmEmbedShell()
            }
        } else if !expectsProfile {
            // Fresh install — auth passed; open empty Main (Edit gates Save).
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
            // Corrupt / unreadable Keychain — stay locked; do not open empty Edit.
            RedMedHaptics.error()
            gate = .locked
            biometryFailed = false
            profileLoadFailed = true
            showUnlockControl = true
        }
    }
}

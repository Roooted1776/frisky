import LocalAuthentication
import UIKit

/// Strict owner authentication. Never call from passerby `tapper.html`,
/// `PublicCardView`, or NFC Preview / Scan — tap-to-view stays ungated
/// (no Face ID, no passcode, no login).
///
/// App unlock is Face ID / Touch ID only (`allowPasscode: false`) so no
/// password pad sits in front of Main / the YOU card. Erase still allows
/// device passcode (`force: true`, default `allowPasscode`). After the first
/// success this process, Edit / NFC / vault skip LA unless `force`.
/// Reuse window is zero so the first app-unlock Face ID is always fresh.
enum BiometricAuth {
    /// Distinguishes a failed scan from cancel / dismiss so lock UI does not
    /// claim “couldn't verify” on every unlock the owner backs out of.
    enum Outcome: Equatable {
        case success
        /// Face ID / Touch ID (or passcode after fallback, when allowed) did not match.
        case notVerified
        /// User or system cancelled; biometry unavailable with no passcode path.
        case declined
        /// App was not interactive yet (cold-start `.inactive`) — caller may retry on `.active`.
        case notInteractive
    }

    /// LAError -1004 (`kLAErrorAppNotInteractive`). Compare by raw code — Swift
    /// case naming has flipped between `.appNotInteractive` and `.notInteractive`
    /// across SDKs, and referencing the wrong one fails the build.
    private static let notInteractiveLACode = -1004

    /// First successful owner unlock this process. Later gates skip the sheet.
    private static var didUnlockThisLaunch = false

    static func authenticate(
        reason: String,
        force: Bool = false,
        allowPasscode: Bool = true,
        completion: @escaping (Outcome) -> Void
    ) {
        if didUnlockThisLaunch, !force {
            let finish = { completion(.success) }
            if Thread.isMainThread {
                finish()
            } else {
                DispatchQueue.main.async(execute: finish)
            }
            return
        }
        let context = makeContext(allowPasscode: allowPasscode)
        var error: NSError?
        let policy: LAPolicy = allowPasscode
            ? .deviceOwnerAuthentication
            : .deviceOwnerAuthenticationWithBiometrics

        // App unlock: Face ID only — empty fallback title hides Enter Passcode.
        // Erase / lockout recovery: one `.deviceOwnerAuthentication` so the
        // passcode pad stays in-sheet (do not chain a second evaluate).
        guard context.canEvaluatePolicy(policy, error: &error) else {
            #if targetEnvironment(simulator)
            let present = {
                presentSimulatorPrompt(
                    reason: reason,
                    allowPasscode: allowPasscode,
                    completion: completion
                )
            }
            if Thread.isMainThread {
                present()
            } else {
                DispatchQueue.main.async(execute: present)
            }
            #else
            let failOutcome: Outcome = isNotInteractive(error) ? .notInteractive : .declined
            let finish = { completion(failOutcome) }
            if Thread.isMainThread {
                finish()
            } else {
                DispatchQueue.main.async(execute: finish)
            }
            #endif
            return
        }

        context.evaluatePolicy(policy, localizedReason: reason) { success, evalError in
            let finish = {
                context.invalidate()
                if success {
                    didUnlockThisLaunch = true
                    completion(.success)
                } else {
                    completion(outcome(for: evalError))
                }
            }
            // LA callbacks are off-main; hop only when needed.
            if Thread.isMainThread {
                finish()
            } else {
                DispatchQueue.main.async(execute: finish)
            }
        }
    }

    private static func makeContext(allowPasscode: Bool) -> LAContext {
        let context = LAContext()
        // No Face ID / Touch ID reuse across gates — every unlock is fresh.
        context.touchIDAuthenticationAllowableReuseDuration = 0
        context.localizedCancelTitle = "Cancel"
        if allowPasscode {
            // Default system fallback ("Enter Passcode") stays inside this evaluation.
        } else {
            // Empty title hides the passcode / password button on Face ID.
            context.localizedFallbackTitle = ""
        }
        return context
    }

    /// True when LocalAuthentication refused because the app was not interactive.
    private static func isNotInteractive(_ error: Error?) -> Bool {
        guard let error else { return false }
        let ns = error as NSError
        return ns.domain == LAErrorDomain && ns.code == notInteractiveLACode
    }

    /// Map LAError to Outcome — only a mismatch is `notVerified`.
    private static func outcome(for error: Error?) -> Outcome {
        guard let la = error as? LAError else { return .declined }
        if la.code == .authenticationFailed {
            // Face ID / Touch ID / passcode did not match.
            return .notVerified
        }
        if isNotInteractive(la) {
            // evaluatePolicy before the window can present — retry when `.active`.
            return .notInteractive
        }
        // userCancel, systemCancel, appCancel, userFallback (if ever), etc.
        return .declined
    }

    #if targetEnvironment(simulator)
    private static func presentSimulatorPrompt(
        reason: String,
        allowPasscode: Bool,
        completion: @escaping (Outcome) -> Void
    ) {
        guard let top = topViewController() else {
            completion(.declined)
            return
        }
        let alert = UIAlertController(
            title: allowPasscode ? "Face ID or Passcode" : "Face ID",
            message: reason,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Don't Allow", style: .cancel) { _ in
            completion(.declined)
        })
        alert.addAction(UIAlertAction(title: "Authenticate", style: .default) { _ in
            didUnlockThisLaunch = true
            completion(.success)
        })
        top.present(alert, animated: true)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first
        guard var top = window?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
    #endif
}

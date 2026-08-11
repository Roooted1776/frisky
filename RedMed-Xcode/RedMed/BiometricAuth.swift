import LocalAuthentication
import UIKit

/// Strict owner authentication — Face ID / Touch ID first; device passcode on fallback / lockout.
/// Reuse window is zero so every gate re-prompts (Edit, NFC write, vault, app unlock).
enum BiometricAuth {
    /// Distinguishes a failed scan from cancel / dismiss so lock UI does not
    /// claim “couldn't verify” on every Accept that the owner backs out of.
    enum Outcome: Equatable {
        case success
        /// Face ID / Touch ID (or passcode after fallback) did not match.
        case notVerified
        /// User or system cancelled; biometry unavailable with no passcode path.
        case declined
    }

    static func authenticate(reason: String, completion: @escaping (Outcome) -> Void) {
        // Face ID is unreliable / often disabled while FaceTime screen share or
        // Screen Recording is active — go straight to device passcode.
        if UIScreen.main.isCaptured {
            authenticateWithDevicePasscode(reason: reason, completion: completion)
            return
        }

        let context = makeContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.localizedFallbackTitle = "Passcode"
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            ) { success, evalError in
                DispatchQueue.main.async {
                    context.invalidate()
                    if success {
                        completion(.success)
                        return
                    }
                    // Fallback / lockout / biometry unavailable → device passcode.
                    if shouldOfferPasscodeFallback(evalError) {
                        authenticateWithDevicePasscode(reason: reason, completion: completion)
                    } else {
                        completion(outcome(for: evalError))
                    }
                }
            }
            return
        }

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            evaluateDeviceOwner(context: context, reason: reason, completion: completion)
            return
        }

        #if targetEnvironment(simulator)
        DispatchQueue.main.async {
            presentSimulatorPrompt(reason: reason, completion: completion)
        }
        #else
        DispatchQueue.main.async { completion(.declined) }
        #endif
    }

    private static func makeContext() -> LAContext {
        let context = LAContext()
        // No Face ID / Touch ID reuse across gates — every unlock is fresh.
        context.touchIDAuthenticationAllowableReuseDuration = 0
        context.localizedCancelTitle = "Cancel"
        return context
    }

    private static func shouldOfferPasscodeFallback(_ error: Error?) -> Bool {
        guard let la = error as? LAError else { return false }
        switch la.code {
        case .userFallback, .biometryLockout, .biometryNotAvailable:
            // Passcode tap, lockout, or Face ID disabled (common during screen share).
            return true
        default:
            // Cancel / failed scan → stay gated; user must retry Face ID.
            return false
        }
    }

    /// Map LAError to Outcome — only a mismatch is `notVerified`.
    private static func outcome(for error: Error?) -> Outcome {
        guard let la = error as? LAError else { return .declined }
        switch la.code {
        case .authenticationFailed:
            // Face ID / Touch ID / passcode did not match.
            return .notVerified
        default:
            // userCancel, systemCancel, appCancel, etc.
            return .declined
        }
    }

    private static func authenticateWithDevicePasscode(
        reason: String,
        completion: @escaping (Outcome) -> Void
    ) {
        let context = makeContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(.declined)
            return
        }
        evaluateDeviceOwner(context: context, reason: reason, completion: completion)
    }

    private static func evaluateDeviceOwner(
        context: LAContext,
        reason: String,
        completion: @escaping (Outcome) -> Void
    ) {
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evalError in
            DispatchQueue.main.async {
                context.invalidate()
                if success {
                    completion(.success)
                } else {
                    completion(outcome(for: evalError))
                }
            }
        }
    }

    #if targetEnvironment(simulator)
    private static func presentSimulatorPrompt(reason: String, completion: @escaping (Outcome) -> Void) {
        guard let top = topViewController() else {
            completion(.declined)
            return
        }
        let alert = UIAlertController(
            title: "Face ID or Passcode",
            message: reason,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Don't Allow", style: .cancel) { _ in
            completion(.declined)
        })
        alert.addAction(UIAlertAction(title: "Authenticate", style: .default) { _ in
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

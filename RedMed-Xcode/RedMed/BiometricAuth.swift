import LocalAuthentication
import UIKit

/// Strict owner authentication — Face ID / Touch ID first; device passcode on fallback / lockout.
/// Reuse window is zero so every gate re-prompts (Edit, NFC write, vault, app unlock).
enum BiometricAuth {
    static func authenticate(reason: String, completion: @escaping (Bool) -> Void) {
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
                        completion(true)
                        return
                    }
                    // Fallback / lockout / failed attempts → require device passcode.
                    if shouldOfferPasscodeFallback(evalError) {
                        authenticateWithDevicePasscode(reason: reason, completion: completion)
                    } else {
                        completion(false)
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
        DispatchQueue.main.async { completion(false) }
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
        case .userFallback, .biometryLockout:
            // Explicit Passcode tap, or Face ID locked out after failed attempts.
            return true
        default:
            // Cancel / failed scan → stay gated; user must retry Face ID.
            return false
        }
    }

    private static func authenticateWithDevicePasscode(
        reason: String,
        completion: @escaping (Bool) -> Void
    ) {
        let context = makeContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            completion(false)
            return
        }
        evaluateDeviceOwner(context: context, reason: reason, completion: completion)
    }

    private static func evaluateDeviceOwner(
        context: LAContext,
        reason: String,
        completion: @escaping (Bool) -> Void
    ) {
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            DispatchQueue.main.async {
                context.invalidate()
                completion(success)
            }
        }
    }

    #if targetEnvironment(simulator)
    private static func presentSimulatorPrompt(reason: String, completion: @escaping (Bool) -> Void) {
        guard let top = topViewController() else {
            completion(false)
            return
        }
        let alert = UIAlertController(
            title: "Face ID or Passcode",
            message: reason,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Don't Allow", style: .cancel) { _ in
            completion(false)
        })
        alert.addAction(UIAlertAction(title: "Authenticate", style: .default) { _ in
            completion(true)
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

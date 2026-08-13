import LocalAuthentication
import UIKit

/// Strict owner authentication — Face ID / Touch ID first; device passcode on
/// the same LocalAuthentication evaluation (fallback / lockout / failed scans).
/// Reuse window is zero so every gate re-prompts (Edit, NFC write, vault, app unlock).
///
/// Use a single `.deviceOwnerAuthentication` call — not biometrics-only followed by
/// a second evaluate. A second `.deviceOwnerAuthentication` after `userFallback`
/// prefers Face ID again when biometrics are still available, so tapping Passcode
/// re-scans instead of opening the passcode pad.
enum BiometricAuth {
    /// Distinguishes a failed scan from cancel / dismiss so lock UI does not
    /// claim “couldn't verify” on every unlock the owner backs out of.
    enum Outcome: Equatable {
        case success
        /// Face ID / Touch ID (or passcode after fallback) did not match.
        case notVerified
        /// User or system cancelled; biometry unavailable with no passcode path.
        case declined
    }

    static func authenticate(reason: String, completion: @escaping (Outcome) -> Void) {
        let context = makeContext()
        var error: NSError?

        // One evaluation: system shows Face ID / Touch ID first, then Enter
        // Passcode in-sheet (including after failed scans / lockout). Screen
        // share often disables Face ID — same policy still reaches passcode.
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            #if targetEnvironment(simulator)
            DispatchQueue.main.async {
                presentSimulatorPrompt(reason: reason, completion: completion)
            }
            #else
            DispatchQueue.main.async { completion(.declined) }
            #endif
            return
        }

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

    private static func makeContext() -> LAContext {
        let context = LAContext()
        // No Face ID / Touch ID reuse across gates — every unlock is fresh.
        context.touchIDAuthenticationAllowableReuseDuration = 0
        context.localizedCancelTitle = "Cancel"
        // Default system fallback ("Enter Passcode") stays inside this evaluation.
        // Do not set localizedFallbackTitle — a custom title with a biometrics-only
        // policy hands userFallback to the app and invites a second Face ID prompt.
        return context
    }

    /// Map LAError to Outcome — only a mismatch is `notVerified`.
    private static func outcome(for error: Error?) -> Outcome {
        guard let la = error as? LAError else { return .declined }
        switch la.code {
        case .authenticationFailed:
            // Face ID / Touch ID / passcode did not match.
            return .notVerified
        default:
            // userCancel, systemCancel, appCancel, userFallback (if ever), etc.
            return .declined
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

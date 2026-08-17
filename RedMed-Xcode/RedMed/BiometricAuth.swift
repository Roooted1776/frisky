import LocalAuthentication
import UIKit

/// Strict owner authentication — Face ID / Touch ID first; device passcode on
/// the same LocalAuthentication evaluation (fallback / lockout / failed scans).
/// Owner-only gates: app unlock, Edit, NFC write, vault, erase. Never call from
/// passerby `tapper.html`, `PublicCardView`, or NFC Preview / Scan shells —
/// tap-to-view stays ungated.
/// Reuse window is zero for Edit / NFC write / vault. App lock may pass a short
/// `allowableReuseDuration` so the Face ID that just opened the phone admits
/// the owner into Main without a second scan or tapping the icon again.
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
        /// App was not interactive yet (cold-start `.inactive`) — caller may retry on `.active`.
        case notInteractive
    }

    /// App lock only — device Face ID that just unlocked the phone / opened
    /// RedMed counts. Long enough to cover lock-screen → icon, short enough
    /// that a later grab still gets a fresh scan. Other gates stay at `0`.
    static let appLockReuseDuration: TimeInterval = 8

    /// LAError -1004 (`kLAErrorAppNotInteractive`). Compare by raw code — Swift
    /// case naming has flipped between `.appNotInteractive` and `.notInteractive`
    /// across SDKs, and referencing the wrong one fails the build.
    private static let notInteractiveLACode = -1004

    static func authenticate(
        reason: String,
        allowableReuseDuration: TimeInterval = 0,
        completion: @escaping (Outcome) -> Void
    ) {
        let context = makeContext(allowableReuseDuration: allowableReuseDuration)
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
            let failOutcome: Outcome = isNotInteractive(error) ? .notInteractive : .declined
            DispatchQueue.main.async { completion(failOutcome) }
            #endif
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, evalError in
            // Always hop a main turn — even when LA already called back on main.
            // Sync apply during Face ID teardown leaves SwiftUI on the lock shell
            // until the owner taps the app again.
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

    private static func makeContext(allowableReuseDuration: TimeInterval) -> LAContext {
        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = allowableReuseDuration
        context.localizedCancelTitle = "Cancel"
        // Default system fallback ("Enter Passcode") stays inside this evaluation.
        // Do not set localizedFallbackTitle — a custom title with a biometrics-only
        // policy hands userFallback to the app and invites a second Face ID prompt.
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

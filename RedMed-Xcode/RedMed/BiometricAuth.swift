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
///
/// On success the `LAContext` is **parked** (not invalidated) so
/// `KeychainStore.load(context:)` can use `kSecUseAuthenticationContext`
/// without a second Face ID sheet. Background / consume clears the park.
enum BiometricAuth {
    enum Outcome: Equatable {
        case success
        case notVerified
        case declined
        case notInteractive
    }

    private static let notInteractiveLACode = -1004

    private static var didUnlockThisLaunch = false

    /// Authenticated context for SecItem after a successful evaluate.
    private static let parkLock = NSLock()
    private static var parkedContext: LAContext?

    /// Seconds the parked context may satisfy SecItem without a new Face ID.
    /// Covers unlock → Keychain load → first persist; background clears earlier.
    private static let secItemReuseDuration: TimeInterval = 60

    static func authenticate(
        reason: String,
        force: Bool = false,
        allowPasscode: Bool = true,
        allowableReuseDuration: TimeInterval = 0,
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
        let context = makeContext(
            allowPasscode: allowPasscode,
            allowableReuseDuration: max(allowableReuseDuration, secItemReuseDuration)
        )
        var error: NSError?
        let policy: LAPolicy = allowPasscode
            ? .deviceOwnerAuthentication
            : .deviceOwnerAuthenticationWithBiometrics

        guard context.canEvaluatePolicy(policy, error: &error) else {
            #if targetEnvironment(simulator)
            DispatchQueue.main.async {
                presentSimulatorPrompt(
                    reason: reason,
                    allowPasscode: allowPasscode,
                    completion: completion
                )
            }
            #else
            let failOutcome: Outcome = isNotInteractive(error) ? .notInteractive : .declined
            DispatchQueue.main.async { completion(failOutcome) }
            #endif
            return
        }

        context.evaluatePolicy(policy, localizedReason: reason) { success, evalError in
            DispatchQueue.main.async {
                if success {
                    didUnlockThisLaunch = true
                    // Keep context alive for Keychain SecItem (do not invalidate yet).
                    park(context)
                    completion(.success)
                } else {
                    context.invalidate()
                    clearPark()
                    completion(outcome(for: evalError))
                }
            }
        }
    }

    /// LAContext from the latest successful evaluate, if still valid for SecItem.
    static func authenticationContext() -> LAContext? {
        parkLock.lock()
        defer { parkLock.unlock() }
        return parkedContext
    }

    /// Take the parked context for a SecItem read (still left parked for reuse).
    static func peekAuthenticationContext() -> LAContext? {
        authenticationContext()
    }

    /// Drop the parked context (background, erase, failed Keychain).
    static func clearAuthenticationContext() {
        clearPark()
    }

    private static func park(_ context: LAContext) {
        parkLock.lock()
        parkedContext?.invalidate()
        parkedContext = context
        parkLock.unlock()
    }

    private static func clearPark() {
        parkLock.lock()
        parkedContext?.invalidate()
        parkedContext = nil
        parkLock.unlock()
    }

    private static func makeContext(
        allowPasscode: Bool,
        allowableReuseDuration: TimeInterval
    ) -> LAContext {
        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = allowableReuseDuration
        context.localizedCancelTitle = "Cancel"
        if !allowPasscode {
            context.localizedFallbackTitle = ""
        }
        return context
    }

    private static func isNotInteractive(_ error: Error?) -> Bool {
        guard let error else { return false }
        let ns = error as NSError
        return ns.domain == LAErrorDomain && ns.code == notInteractiveLACode
    }

    private static func outcome(for error: Error?) -> Outcome {
        guard let la = error as? LAError else { return .declined }
        if la.code == .authenticationFailed {
            return .notVerified
        }
        if isNotInteractive(la) {
            return .notInteractive
        }
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
            // Simulator has no real ACL biometry — empty park; Keychain uses legacy path.
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

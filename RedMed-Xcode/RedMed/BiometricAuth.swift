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
        /// Face ID / Touch ID cannot run (lockout, not enrolled, not available).
        case unavailable
    }

    private static let notInteractiveLACode = -1004

    private static var didUnlockThisLaunch = false

    /// Authenticated context for SecItem after a successful evaluate.
    private static let parkLock = NSLock()
    private static var parkedContext: LAContext?
    /// Live `evaluatePolicy` context. Invalidate before starting a new one —
    /// a second evaluate while the first is up fails immediately (dead Proceed).
    private static var inFlightContext: LAContext?

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

        let cancelledLiveContext = cancelInFlight()

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
            let failOutcome: Outcome
            if isNotInteractive(error) {
                failOutcome = .notInteractive
            } else if isUnavailable(error) {
                failOutcome = .unavailable
            } else {
                failOutcome = .declined
            }
            DispatchQueue.main.async { completion(failOutcome) }
            #endif
            return
        }

        setInFlight(context)
        let runEvaluate = {
            context.evaluatePolicy(policy, localizedReason: reason) { success, evalError in
                DispatchQueue.main.async {
                    clearInFlight(ifSame: context)
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
        if cancelledLiveContext {
            // Only a retry right behind a cancelled/leftover sheet needs
            // this wait — that LAContext needs real wall-clock time to tear
            // down, not just the next run loop turn. Too short and
            // evaluatePolicy fails immediately with no sheet shown (dead
            // Proceed, no Face ID prompt, no system success animation). A
            // fresh first attempt (nothing was in flight) has no such
            // leftover to wait out, so it runs immediately.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: runEvaluate)
        } else {
            runEvaluate()
        }
    }

    /// Kill a hung / leftover Face ID sheet so Proceed can start a fresh one.
    /// Returns whether a live context was actually cancelled — callers only
    /// need to wait out the teardown when this is true.
    @discardableResult
    static func cancelInFlight() -> Bool {
        parkLock.lock()
        let ctx = inFlightContext
        inFlightContext = nil
        parkLock.unlock()
        ctx?.invalidate()
        return ctx != nil
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

    private static func setInFlight(_ context: LAContext) {
        parkLock.lock()
        inFlightContext = context
        parkLock.unlock()
    }

    private static func clearInFlight(ifSame context: LAContext) {
        parkLock.lock()
        if inFlightContext === context {
            inFlightContext = nil
        }
        parkLock.unlock()
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

    private static func isUnavailable(_ error: Error?) -> Bool {
        guard let error else { return false }
        let ns = error as NSError
        guard ns.domain == LAErrorDomain else { return false }
        switch ns.code {
        case LAError.biometryNotAvailable.rawValue,
             LAError.biometryNotEnrolled.rawValue,
             LAError.biometryLockout.rawValue,
             LAError.passcodeNotSet.rawValue:
            return true
        default:
            return false
        }
    }

    private static func outcome(for error: Error?) -> Outcome {
        guard let la = error as? LAError else {
            return isUnavailable(error) ? .unavailable : .declined
        }
        if la.code == .authenticationFailed {
            return .notVerified
        }
        if isNotInteractive(la) {
            return .notInteractive
        }
        if isUnavailable(la) {
            return .unavailable
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                guard let retry = topViewController() else {
                    completion(.unavailable)
                    return
                }
                presentAlert(
                    on: retry,
                    reason: reason,
                    allowPasscode: allowPasscode,
                    completion: completion
                )
            }
            return
        }
        presentAlert(
            on: top,
            reason: reason,
            allowPasscode: allowPasscode,
            completion: completion
        )
    }

    private static func presentAlert(
        on top: UIViewController,
        reason: String,
        allowPasscode: Bool,
        completion: @escaping (Outcome) -> Void
    ) {
        if top.presentedViewController != nil {
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

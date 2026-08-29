import LocalAuthentication
import UIKit

/// Strict owner authentication. Never call from passerby `tapper.html`,
/// NFC Preview / Scan — tap-to-view stays ungated
/// (no Face ID, no passcode, no login).
///
/// Edit, Save, and Erase pass `force: true`. NFC write and tapper do not.
/// There is no process-wide skip flag.
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
        case unavailable(UnavailableReason)
        case timedOut
    }

    enum UnavailableReason: Equatable {
        case notEnrolled
        case lockout
        case passcodeNotSet
        case notAvailable

        var message: String {
            switch self {
            case .notEnrolled:
                return "Face ID isn't set up on this iPhone. Add it in Settings, then reopen RedMed."
            case .lockout:
                return "Face ID locked after 5 failed attempts. Unlock this iPhone with its passcode, then reopen RedMed."
            case .passcodeNotSet:
                return "Set a device passcode in Settings to use Face ID."
            case .notAvailable:
                return "Face ID isn't available on this device."
            }
        }
    }

    private static let notInteractiveLACode = -1004
    private static let parkLock = NSLock()
    private static var parkedContext: LAContext?
    private static var inFlightContext: LAContext?
    private static var lastSessionEndedAt: Date?
    private static let evaluateCooldown: TimeInterval = 0.28
    private static let evaluateHangTimeout: TimeInterval = 90

    static func authenticate(
        reason: String,
        force: Bool,
        allowPasscode: Bool = true,
        completion: @escaping (Outcome) -> Void
    ) {
        _ = force
        #if targetEnvironment(simulator)
        _ = cancelInFlight()
        markSessionEnded()
        if Thread.isMainThread {
            completion(.success)
        } else {
            DispatchQueue.main.async { completion(.success) }
        }
        #else
        let cancelledLiveContext = cancelInFlight()
        let context = makeContext(allowPasscode: allowPasscode)
        var error: NSError?
        let policy: LAPolicy = allowPasscode
            ? .deviceOwnerAuthentication
            : .deviceOwnerAuthenticationWithBiometrics

        let canEvaluate = context.canEvaluatePolicy(policy, error: &error)
        RedMedSignpost.trace("canEvaluatePolicy=\(canEvaluate) error=\(String(describing: error))")
        guard canEvaluate else {
            let failOutcome: Outcome
            if isNotInteractive(error) {
                failOutcome = .notInteractive
            } else if let reason = unavailableReason(error) {
                failOutcome = .unavailable(reason)
            } else {
                failOutcome = .declined
            }
            DispatchQueue.main.async { completion(failOutcome) }
            return
        }

        setInFlight(context)
        var didComplete = false
        let finish: (Outcome) -> Void = { result in
            guard !didComplete else { return }
            didComplete = true
            completion(result)
        }
        let runEvaluate = {
            RedMedSignpost.trace("evaluatePolicy calling now")
            DispatchQueue.main.asyncAfter(deadline: .now() + evaluateHangTimeout) {
                guard !didComplete else { return }
                clearInFlight(ifSame: context)
                context.invalidate()
                clearPark()
                markSessionEnded()
                finish(.timedOut)
            }
            context.evaluatePolicy(policy, localizedReason: reason) { success, evalError in
                RedMedSignpost.trace("evaluatePolicy raw callback: success=\(success) error=\(String(describing: evalError))")
                DispatchQueue.main.async {
                    guard !didComplete else { return }
                    clearInFlight(ifSame: context)
                    markSessionEnded()
                    if success {
                        park(context)
                        finish(.success)
                    } else {
                        context.invalidate()
                        clearPark()
                        finish(outcome(for: evalError))
                    }
                }
            }
        }
        let wait = max(cancelledLiveContext ? evaluateCooldown : 0, remainingEvaluateCooldown())
        if wait > 0.01 {
            DispatchQueue.main.asyncAfter(deadline: .now() + wait, execute: runEvaluate)
        } else {
            runEvaluate()
        }
        #endif
    }

    static var isEvaluating: Bool {
        parkLock.lock()
        defer { parkLock.unlock() }
        #if targetEnvironment(simulator)
        return inFlightContext != nil || simulatorPromptUp
        #else
        return inFlightContext != nil
        #endif
    }

    #if targetEnvironment(simulator)
    static var isSimulatorAlertVisible: Bool {
        parkLock.lock()
        let up = simulatorPromptUp
        parkLock.unlock()
        guard up else { return false }
        guard let top = topViewController(), top.view.window?.isKeyWindow == true else {
            return false
        }
        return top is UIAlertController || top.presentedViewController is UIAlertController
    }
    #endif

    @discardableResult
    static func cancelInFlight() -> Bool {
        parkLock.lock()
        let ctx = inFlightContext
        inFlightContext = nil
        #if targetEnvironment(simulator)
        let simUp = simulatorPromptUp
        simulatorPromptUp = false
        let simAlert = simulatorAlert
        simulatorAlert = nil
        #endif
        parkLock.unlock()
        ctx?.invalidate()
        #if targetEnvironment(simulator)
        if let simAlert {
            simAlert.dismiss(animated: false)
        }
        if ctx != nil || simUp { markSessionEnded() }
        return ctx != nil || simUp
        #else
        if ctx != nil { markSessionEnded() }
        return ctx != nil
        #endif
    }

    static func authenticationContext() -> LAContext? {
        parkLock.lock()
        defer { parkLock.unlock() }
        return parkedContext
    }

    static func peekAuthenticationContext() -> LAContext? {
        authenticationContext()
    }

    static func clearAuthenticationContext() {
        clearPark()
    }

    private static func markSessionEnded() {
        parkLock.lock()
        lastSessionEndedAt = Date()
        parkLock.unlock()
    }

    private static func remainingEvaluateCooldown() -> TimeInterval {
        parkLock.lock()
        let ended = lastSessionEndedAt
        parkLock.unlock()
        guard let ended else { return 0 }
        return max(0, evaluateCooldown - Date().timeIntervalSince(ended))
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

    private static func makeContext(allowPasscode: Bool) -> LAContext {
        let context = LAContext()
        context.touchIDAuthenticationAllowableReuseDuration = 0
        context.localizedCancelTitle = "Cancel"
        if allowPasscode {
            context.localizedFallbackTitle = "Enter Passcode"
        } else {
            context.localizedFallbackTitle = ""
        }
        return context
    }

    private static func isNotInteractive(_ error: Error?) -> Bool {
        guard let error else { return false }
        let ns = error as NSError
        return ns.domain == LAErrorDomain && ns.code == notInteractiveLACode
    }

    private static func unavailableReason(_ error: Error?) -> UnavailableReason? {
        guard let error else { return nil }
        let ns = error as NSError
        guard ns.domain == LAErrorDomain else { return nil }
        switch ns.code {
        case LAError.biometryNotEnrolled.rawValue:
            return .notEnrolled
        case LAError.biometryLockout.rawValue:
            return .lockout
        case LAError.passcodeNotSet.rawValue:
            return .passcodeNotSet
        case LAError.biometryNotAvailable.rawValue:
            return .notAvailable
        default:
            return nil
        }
    }

    private static func outcome(for error: Error?) -> Outcome {
        if let reason = unavailableReason(error) {
            return .unavailable(reason)
        }
        guard let la = error as? LAError else {
            return .declined
        }
        if la.code == .authenticationFailed {
            return .notVerified
        }
        if isNotInteractive(la) {
            return .notInteractive
        }
        return .declined
    }

    #if targetEnvironment(simulator)
    private static var simulatorPromptUp = false
    private static weak var simulatorAlert: UIAlertController?

    private static func presentSimulatorPrompt(
        reason: String,
        allowPasscode: Bool,
        completion: @escaping (Outcome) -> Void
    ) {
        presentSimulatorPrompt(reason: reason, allowPasscode: allowPasscode, attempt: 0, completion: completion)
    }

    private static func presentSimulatorPrompt(
        reason: String,
        allowPasscode: Bool,
        attempt: Int,
        completion: @escaping (Outcome) -> Void
    ) {
        if let top = topViewController(), top.view.window != nil {
            presentAlert(
                on: top,
                reason: reason,
                allowPasscode: allowPasscode,
                completion: completion
            )
            return
        }
        guard attempt < 20 else {
            parkLock.lock()
            simulatorPromptUp = false
            parkLock.unlock()
            completion(.notInteractive)
            return
        }
        DispatchQueue.main.async {
            presentSimulatorPrompt(
                reason: reason,
                allowPasscode: allowPasscode,
                attempt: attempt + 1,
                completion: completion
            )
        }
    }

    private static func presentAlert(
        on top: UIViewController,
        reason: String,
        allowPasscode: Bool,
        completion: @escaping (Outcome) -> Void
    ) {
        let alert = UIAlertController(
            title: allowPasscode ? "Face ID or Passcode" : "Face ID",
            message: reason,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Don't Allow", style: .cancel) { _ in
            parkLock.lock()
            simulatorPromptUp = false
            simulatorAlert = nil
            parkLock.unlock()
            markSessionEnded()
            completion(.declined)
        })
        alert.addAction(UIAlertAction(title: "Authenticate", style: .default) { _ in
            parkLock.lock()
            simulatorPromptUp = false
            simulatorAlert = nil
            parkLock.unlock()
            markSessionEnded()
            completion(.success)
        })
        simulatorAlert = alert
        parkLock.lock()
        simulatorPromptUp = true
        parkLock.unlock()
        top.present(alert, animated: false)
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow && $0.rootViewController != nil })
        guard var top = window?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
    #endif

    static let deniedAlertTitle = "Authentication Failed"

    static func deniedAlertMessage(action: String) -> String {
        "Face ID or passcode is required to \(action) your RedMed profile."
    }
}

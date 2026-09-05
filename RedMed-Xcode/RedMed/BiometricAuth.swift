import LocalAuthentication
import UIKit

/// Strict owner authentication. Never call from passerby `tapper.html`,
/// NFC Preview / Scan — tap-to-view stays ungated
/// (no Face ID, no passcode, no login).
///
/// First-launch consent, owner RedMed user view, Edit, Save, and Erase
/// pass `force: true`. NFC write, 911, Aid, later app launch, and tapper
/// do not (later opens Face ID on the RedMed user page when a stored ID
/// exists).
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
        /// Face ID / Touch ID cannot run right now. Retrying the same way
        /// never fixes this — each reason needs a different user action.
        case unavailable(UnavailableReason)
        /// `evaluatePolicy` never called back at all within `evaluateHangTimeout`
        /// — the same "no sheet ever presents" OS-level hang documented for
        /// cold launch (see AGENTS.md) can in principle hit any caller. Treat
        /// like `.declined`: quietly reset and let the user retry.
        case timedOut
    }

    /// Why `canEvaluatePolicy` / `evaluatePolicy` reports biometrics can't
    /// run. Distinct from `.notVerified` (a scan that failed to match) —
    /// these are states no amount of retrying will resolve.
    enum UnavailableReason: Equatable {
        case notEnrolled
        case lockout
        case passcodeNotSet
        case notAvailable

        var message: String {
            switch self {
            case .notEnrolled:
                return "Face ID isn't set up on this iPhone. Add it in Settings, then try again."
            case .lockout:
                return "Face ID locked after 5 failed attempts. Unlock this iPhone with its passcode, then try again."
            case .passcodeNotSet:
                return "Set a device passcode in Settings to use Face ID."
            case .notAvailable:
                return "Face ID isn't available on this device."
            }
        }
    }

    private static let notInteractiveLACode = -1004

    /// Authenticated context for SecItem after a successful evaluate.
    private static let parkLock = NSLock()
    private static var parkedContext: LAContext?
    /// Live `evaluatePolicy` context. Invalidate before starting a new one —
    /// a second evaluate while the first is up fails immediately (dead prompt).
    private static var inFlightContext: LAContext?
    /// Last time an evaluate ended or was cancelled. A new evaluate inside
    /// `evaluateCooldown` of this fails with no sheet (dead Face ID).
    private static var lastSessionEndedAt: Date?
    private static let evaluateCooldown: TimeInterval = 0.28

    /// Backstop for a hung `evaluatePolicy` that never calls back at all.
    /// Apple does **not** timeout the system sheet — there is no LA API for
    /// it. This clock is ours, started when `evaluatePolicy` is actually
    /// invoked (not at `authenticate` entry / cooldown). Callers (Erase,
    /// Edit, Save) hard-guard re-entrancy on their own busy flag, so a
    /// completion that never fires would brick that action until force-quit.
    private static let evaluateHangTimeout: TimeInterval = 90

    /// `force` is kept so every call site stays explicit. There is no
    /// process-wide skip — every call evaluates a fresh policy.
    ///
    /// `touchIDAuthenticationAllowableReuseDuration` is always 0. Apple's
    /// max is 300s (`LATouchIDAuthenticationMaximumAllowableReuseDuration`);
    /// a non-zero value lets `evaluatePolicy` succeed off a recent *device*
    /// unlock with no new Face ID sheet — which would skip the owner gate.
    /// The parked `LAContext` is what lets SecItem skip a second sheet after
    /// a successful evaluate; that does not need this property.
    static func authenticate(
        reason: String,
        force: Bool,
        allowPasscode: Bool = true,
        completion: @escaping (Outcome) -> Void
    ) {
        _ = force

        // Simulator: never evaluatePolicy and never a UIKit alert.
        // Auto-succeed so first-launch consent / RedMed view / Edit /
        // Save / Erase can proceed without a device. Device still uses
        // real Face ID.
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
        // Only one of {real callback, hang timeout} may ever act — whichever
        // reaches this guard first on the (serial) main queue wins outright,
        // so a very late real callback after a timeout can't re-park an
        // already-invalidated context or double-fire the caller's completion.
        var didComplete = false
        let finish: (Outcome) -> Void = { result in
            guard !didComplete else { return }
            didComplete = true
            completion(result)
        }
        let runEvaluate = {
            RedMedSignpost.trace("evaluatePolicy calling now")
            // Clock starts at the actual system call, not at authenticate()
            // entry — the 0.28s teardown cooldown must not eat this budget.
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
                        // Keep context alive for Keychain SecItem (do not invalidate yet).
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
        // Wait out leftover LAContext teardown — same-turn retry after
        // userCancel / .notInteractive / cancelInFlight fails immediately
        // with no Face ID sheet and no system success animation (dead prompt).
        let wait = max(cancelledLiveContext ? evaluateCooldown : 0, remainingEvaluateCooldown())
        if wait > 0.01 {
            DispatchQueue.main.asyncAfter(deadline: .now() + wait, execute: runEvaluate)
        } else {
            runEvaluate()
        }
        #endif
    }

    /// Live `evaluatePolicy` in progress (including the teardown wait).
    /// Scene `.inactive` during this is the Face ID sheet on the owner
    /// RedMed user view / Edit / Save / Erase — do not treat it as a leave.
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
    /// True only if the Authenticate alert is on the key window.
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

    /// Kill a hung / leftover Face ID sheet so the owner RedMed view /
    /// Edit / Save / Erase can start a fresh one.
    /// Returns whether a live context was actually cancelled — callers only
    /// need to wait out the teardown when this is true.
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

    /// `evaluatePolicy` before a key window never presents a sheet and can
    /// hang until the hang clock. ConsentGate and the owner RedMed view
    /// both wait for this (and retry on `UIWindow.didBecomeKeyNotification`).
    static var hasKeyWindow: Bool {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .contains(where: \.isKeyWindow)
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
            // Simulator has no real ACL biometry — empty park; Keychain uses legacy path.
            completion(.success)
        })
        simulatorAlert = alert
        parkLock.lock()
        simulatorPromptUp = true
        parkLock.unlock()
        top.present(alert, animated: false)
    }

    private static func topViewController() -> UIViewController? {
        // Key window only.
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap(\.windows).first(where: { $0.isKeyWindow && $0.rootViewController != nil })
        guard var top = window?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
    #endif

    /// Shared "Authentication Failed" alert copy for `.declined` / `.notVerified`
    /// outcomes on Edit / Save (and similar owner-gated actions) — kept in one
    /// place so the wording can't drift between call sites.
    static let deniedAlertTitle = "Authentication Failed"

    static func deniedAlertMessage(action: String) -> String {
        "Face ID or passcode is required to \(action) your RedMed profile."
    }

    static let unavailableAlertTitle = "Face ID Unavailable"
}

/// Foreground unlock for the owner RedMed user page (YOU card).
/// Not an app-wide lock — 911 / Aid / NFC stay reachable without this.
/// Relock on true `.background` only (not `.inactive` / Face ID sheet).
enum OwnerRedMedGate {
    static var isUnlocked = false

    static func unlock() { isUnlocked = true }
    static func lock() { isUnlocked = false }
}

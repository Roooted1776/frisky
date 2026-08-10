import Foundation
import LocalAuthentication

/// Local-only biometric gate for editing the owner's medical profile.
///
/// This is a *UI/tamper* gate, not encryption. The profile is already stored
/// hardware-encrypted in the Keychain (`.WhenUnlockedThisDeviceOnly`). This
/// layer stops someone holding an already-unlocked phone from silently
/// altering the medical record — a realistic threat for a medical ID.
///
/// It deliberately does NOT gate the emergency card that responders read via
/// NFC/URL (`ScannedCardView`); gating that would defeat the point of the app.
enum BiometricGate {

    /// What the device can currently do, so the UI can label the button correctly.
    enum Availability: Equatable {
        case faceID
        case touchID
        case opticID
        case passcodeOnly   // no biometrics enrolled, but a device passcode is set
        case none           // no biometrics and no passcode — nothing to enforce

        var iconSystemName: String {
            switch self {
            case .faceID: return "faceid"
            case .touchID: return "touchid"
            case .opticID: return "opticid"
            case .passcodeOnly, .none: return "lock.fill"
            }
        }

        var editGateTitle: String {
            switch self {
            case .faceID: return "Face ID required to edit"
            case .touchID: return "Touch ID required to edit"
            case .opticID: return "Optic ID required to edit"
            case .passcodeOnly: return "Passcode required to edit"
            case .none: return "Unlock to edit"
            }
        }

        var unlockButtonLabel: String {
            switch self {
            case .faceID: return "Unlock with Face ID"
            case .touchID: return "Unlock with Touch ID"
            case .opticID: return "Unlock with Optic ID"
            case .passcodeOnly: return "Unlock with Passcode"
            case .none: return "Continue"
            }
        }

        var lockSubtitle: String {
            switch self {
            case .faceID: return "Use Face ID to open your medical profile."
            case .touchID: return "Use Touch ID to open your medical profile."
            case .opticID: return "Use Optic ID to open your medical profile."
            case .passcodeOnly: return "Enter your device passcode to open your medical profile."
            case .none: return "Tap to continue."
            }
        }

        var lockUnlockLabel: String { unlockButtonLabel }
    }

    static func availability() -> Availability {
        let context = LAContext()
        var error: NSError?

        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:  return .faceID
            case .touchID: return .touchID
            case .opticID: return .opticID
            default:       return .passcodeOnly
            }
        }
        // No biometrics. Is a passcode at least set?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            return .passcodeOnly
        }
        return .none
    }

    /// Prompts the owner to authenticate.
    ///
    /// Uses `.deviceOwnerAuthentication` (biometrics **with** passcode fallback)
    /// on purpose: this is a medical app, and the owner must never be permanently
    /// locked out of their own emergency information if Face ID fails, is not
    /// enrolled, or the sensor is unavailable. The tradeoff is that the device
    /// passcode also unlocks editing — an acceptable widening of the trust
    /// boundary for owner-only medical data. Switch to
    /// `.deviceOwnerAuthenticationWithBiometrics` if you want biometrics only.
    ///
    /// - Returns: `true` if authenticated (or if the device has no auth to
    ///   enforce — fail-open so the owner is never locked out).
    static func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedFallbackTitle = "Enter Passcode"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // Neither biometrics nor a passcode is configured: there is nothing
            // to enforce, so allow the edit rather than trap the owner out of
            // their own medical record.
            return true
        }

        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            ) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }
}

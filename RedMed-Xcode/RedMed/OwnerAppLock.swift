import SwiftUI
import UIKit

/// Apple does **not** timeout `evaluatePolicy`. These are RedMed backstops.
/// Inactive total is 60s (explicit product choice: slow passcode after a
/// Face ID miss vs ghost-sheet hangs). Keep `BiometricAuth`'s hang clock
/// above this or it will cancel a live passcode first.
///
/// File-level so these can be stored `static let`s. Nested inside
/// `OwnerAppLock<Content>` they inherit the generic parameter, and Swift
/// rejects static stored properties on generic types.
private enum AuthBudget {
    /// Hung evaluate with no system UI (scene `.active`).
    static let noSheetSeconds: TimeInterval = 4.5
    /// GCD twin of `noSheetSeconds` (independent of Task cancellation).
    static let noSheetGCDSeconds: TimeInterval = 5.0
    /// Total wait from lock-cycle start when scene is `.inactive`
    /// (live passcode or ghost sheet) before cancel.
    static let inactiveSheetTotalSeconds: TimeInterval = 60.0
    /// Hung Keychain/profile decode after Face ID already succeeded.
    /// Blank cream here is not a live sheet — surface Proceed fast.
    static let profileLoadSeconds: TimeInterval = 1.2
}

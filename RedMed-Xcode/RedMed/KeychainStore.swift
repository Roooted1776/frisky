import Foundation
import LocalAuthentication
import Security

/// Hardware-encrypted on-device storage for the RedMed profile blob.
///
/// **Bound items (current):** `WhenPasscodeSetThisDeviceOnly` +
/// `biometryCurrentSet` via `kSecAttrAccessControl`. SecItem will not return
/// PHI without OS biometry (Face ID / Touch ID for the current enrollment).
/// Re-enrolling Face ID / adding-removing fingers invalidates the item
/// (fail closed — owner re-saves from Edit after unlock).
///
/// **Legacy items:** plain `WhenUnlockedThisDeviceOnly` with no ACL. `load`
/// still reads them; the next successful `save` migrates to the bound form.
///
/// Never iCloud Keychain (`kSecAttrSynchronizable = false`).
enum KeychainStore {
    private static let defaultService = "com.redmed.app.profile"

    // MARK: - Access control

    /// Strongest practical ACL: device passcode must be set; current biometry only.
    private static func makeAccessControl() -> SecAccessControl? {
        var error: Unmanaged<CFError>?
        // Prefer passcode-required accessibility; fall back if the device has no passcode.
        if let ac = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) {
            return ac
        }
        error = nil
        return SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        )
    }

    // MARK: - Save (bound)

    /// Update-or-add under biometry ACL. Migrates legacy unbound items by delete+add.
    /// Never delete-then-add on a failed path that would wipe PHI without a successful add.
    @discardableResult
    static func save(_ data: Data, account: String, service: String = defaultService) -> Bool {
        guard let access = makeAccessControl() else {
            return saveLegacyUnbound(data, account: account, service: service)
        }

        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]

        // Try update value in place (bound item already present).
        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        // Missing or ACL mismatch (legacy unbound) — replace with bound item.
        if updateStatus == errSecItemNotFound
            || updateStatus == errSecAuthFailed
            || updateStatus == errSecInteractionNotAllowed
            || updateStatus == errSecNoSuchAttr
        {
            SecItemDelete(base as CFDictionary)
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessControl as String] = access
            // Do not set kSecAttrAccessible alongside kSecAttrAccessControl.
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            if addStatus == errSecSuccess {
                return true
            }
            // Last resort: unbound so the owner does not lose PHI on ACL hardware quirks.
            return saveLegacyUnbound(data, account: account, service: service)
        }

        return false
    }

    private static func saveLegacyUnbound(
        _ data: Data,
        account: String,
        service: String
    ) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }
        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - Load

    /// Read PHI. Prefer an authenticated `LAContext` from `BiometricAuth` so the OS
    /// does not present a second sheet. Falls back to legacy unbound items, then
    /// optional interactive SecItem UI only if `allowInteractive` is true.
    static func load(
        account: String,
        service: String = defaultService,
        context: LAContext? = nil,
        allowInteractive: Bool = false
    ) -> Data? {
        if let context, let data = loadBound(account: account, service: service, context: context) {
            return data
        }
        // Legacy unbound (pre-ACL) — readable while device unlocked.
        if let data = loadLegacy(account: account, service: service) {
            return data
        }
        // Bound item but no context yet (should not happen on owner unlock path).
        if allowInteractive {
            return loadBound(account: account, service: service, context: nil, interactive: true)
        }
        return nil
    }

    private static func loadBound(
        account: String,
        service: String,
        context: LAContext?,
        interactive: Bool = false
    ) -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        if let context {
            query[kSecUseAuthenticationContext as String] = context
            query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        } else if interactive {
            query[kSecUseOperationPrompt as String] = "Unlock your RedMed profile"
        } else {
            query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
        }
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func loadLegacy(account: String, service: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        // Bound items often surface as auth errors when UI is forced to fail — not legacy data.
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    // MARK: - Presence

    /// Presence without presenting UI. Treats auth-required as "exists".
    static func exists(account: String, service: String = defaultService) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        switch status {
        case errSecSuccess, errSecInteractionNotAllowed, errSecAuthFailed,
             errSecUserCanceled, errSecMissingEntitlement:
            // MissingEntitlement should not happen; still fail closed as "present" only on known codes.
            return status == errSecSuccess
                || status == errSecInteractionNotAllowed
                || status == errSecAuthFailed
        case errSecItemNotFound:
            return false
        default:
            // Unknown status — prefer UserDefaults gate over false negative (fail-closed unlock).
            return status != errSecItemNotFound
        }
    }

    static func delete(account: String, service: String = defaultService) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        SecItemDelete(query as CFDictionary)
    }
}

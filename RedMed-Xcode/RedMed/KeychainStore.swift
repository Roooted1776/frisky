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
/// `load` automatically uses `BiometricAuth.peekAuthenticationContext()` when
/// no context is passed, so unlock / persist paths do not need plumbing changes.
/// Never iCloud Keychain (`kSecAttrSynchronizable = false`).
enum KeychainStore {
    private static let defaultService = "com.redmed.app.profile"

    private static func makeAccessControl() -> SecAccessControl? {
        var error: Unmanaged<CFError>?
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

        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(base as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        if updateStatus == errSecItemNotFound
            || updateStatus == errSecAuthFailed
            || updateStatus == errSecInteractionNotAllowed
            || updateStatus == errSecNoSuchAttr
        {
            // Replace legacy unbound (or missing) with bound item. Only delete after
            // we are committed to add; if add fails, restore attempt via legacy save.
            var add = base
            add[kSecValueData as String] = data
            add[kSecAttrAccessControl as String] = access
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            if addStatus == errSecSuccess {
                // Remove any duplicate legacy row if both somehow existed (rare).
                return true
            }
            if addStatus == errSecDuplicateItem {
                SecItemDelete(base as CFDictionary)
                if SecItemAdd(add as CFDictionary, nil) == errSecSuccess {
                    return true
                }
            }
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

    /// Read PHI. Uses parked Face ID `LAContext` when available so SecItem does not
    /// present a second sheet. Falls back to legacy unbound items.
    static func load(
        account: String,
        service: String = defaultService,
        context: LAContext? = nil,
        allowInteractive: Bool = false
    ) -> Data? {
        let ctx = context ?? BiometricAuth.peekAuthenticationContext()
        if let ctx, let data = loadBound(account: account, service: service, context: ctx) {
            return data
        }
        if let data = loadLegacy(account: account, service: service) {
            return data
        }
        if allowInteractive {
            return loadBound(account: account, service: service, context: nil, interactive: true)
        }
        // Bound item, no context yet (Face ID still up) — fail closed without UI.
        return loadBound(account: account, service: service, context: nil, interactive: false)
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
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Presence without presenting UI. Auth-required counts as present.
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
        case errSecSuccess, errSecInteractionNotAllowed, errSecAuthFailed:
            return true
        case errSecItemNotFound:
            return false
        default:
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

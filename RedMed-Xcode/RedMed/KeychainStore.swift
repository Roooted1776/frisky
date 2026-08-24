import Foundation
import LocalAuthentication
import Security

/// Hardware-encrypted on-device storage for the RedMed profile blob.
///
/// **Bound items (current):** `WhenPasscodeSetThisDeviceOnly` +
/// `biometryCurrentSet` via `kSecAttrAccessControl`. SecItem will not return
/// PHI without OS biometry (Face ID / Touch ID for the current enrollment).
/// Re-enrolling Face ID / changing fingers invalidates the item (fail closed).
///
/// **Legacy items:** plain accessibility with no ACL. `load` still reads them;
/// a successful read then **migrates** to the bound form (best-effort).
///
/// `load` / `save` use `BiometricAuth.peekAuthenticationContext()` when present
/// so post–Face ID SecItem work does not present a second sheet.
/// Never iCloud Keychain (`kSecAttrSynchronizable = false`).
enum KeychainStore {
    private static let defaultService = "com.redmed.app.profile"

    private static func makeAccessControl() -> SecAccessControl? {
        var error: Unmanaged<CFError>?
        if let ac = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            SecAccessControlCreateFlags.biometryCurrentSet,
            &error
        ) {
            return ac
        }
        error = nil
        return SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            SecAccessControlCreateFlags.biometryCurrentSet,
            &error
        )
    }

    private static func baseQuery(account: String, service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
    }

    /// Attach parked LAContext so ACL items can update/read without a second prompt.
    private static func withAuthContext(_ query: inout [String: Any]) {
        if let ctx = BiometricAuth.peekAuthenticationContext() {
            // Modern replacement for the deprecated kSecUseAuthenticationUIFail
            ctx.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = ctx
        }
    }
    // MARK: - Save

    @discardableResult
    static func save(_ data: Data, account: String, service: String = defaultService) -> Bool {
        guard let access = makeAccessControl() else {
            return saveLegacyUnbound(data, account: account, service: service)
        }

        var query = baseQuery(account: account, service: service)
        withAuthContext(&query)

        let update: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        // Missing, ACL mismatch, or auth — replace with a single bound item.
        if updateStatus == errSecItemNotFound
            || updateStatus == errSecAuthFailed
            || updateStatus == errSecInteractionNotAllowed
            || updateStatus == errSecNoSuchAttr
            || updateStatus == errSecParam
        {
            return replaceWithBound(data, account: account, service: service, access: access)
        }

        // Last resort unbound so Edit Save never silently drops PHI.
        return saveLegacyUnbound(data, account: account, service: service)
    }

    private static func replaceWithBound(
        _ data: Data,
        account: String,
        service: String,
        access: SecAccessControl
    ) -> Bool {
        var del = baseQuery(account: account, service: service)
        withAuthContext(&del)
        SecItemDelete(del as CFDictionary)
        // Also delete without context (legacy row).
        SecItemDelete(baseQuery(account: account, service: service) as CFDictionary)

        var add = baseQuery(account: account, service: service)
        add[kSecValueData as String] = data
        add[kSecAttrAccessControl as String] = access
        // Never set kSecAttrAccessible alongside kSecAttrAccessControl.
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return true
        }
        return saveLegacyUnbound(data, account: account, service: service)
    }

    private static func saveLegacyUnbound(
        _ data: Data,
        account: String,
        service: String
    ) -> Bool {
        let query = baseQuery(account: account, service: service)
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

    static func load(
        account: String,
        service: String = defaultService,
        context: LAContext? = nil,
        allowInteractive: Bool = false
    ) -> Data? {
        let ctx = context ?? BiometricAuth.peekAuthenticationContext()
        if let data = loadBound(account: account, service: service, context: ctx, interactive: false) {
            return data
        }
        if let data = loadLegacy(account: account, service: service) {
            // Upgrade unbound → biometry ACL while we hold auth (best-effort).
            _ = save(data, account: account, service: service)
            return data
        }
        if allowInteractive {
            return loadBound(account: account, service: service, context: nil, interactive: true)
        }
        if ctx != nil {
            return loadBound(account: account, service: service, context: nil, interactive: false)
        }
        return nil
    }

    private static func loadBound(
        account: String,
        service: String,
        context: LAContext?,
        interactive: Bool
    ) -> Data? {
        var query = baseQuery(account: account, service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        if let context {
            // Use the provided context and force no UI
            context.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = context
        } else if interactive {
            // Allow UI – create a fresh context and set the reason
            let ctx = LAContext()
            ctx.localizedReason = "Unlock your RedMed profile"
            query[kSecUseAuthenticationContext as String] = ctx
        } else {
            // Non-interactive – fail if any UI would be required
            let ctx = LAContext()
            ctx.interactionNotAllowed = true
            query[kSecUseAuthenticationContext as String] = ctx
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func loadLegacy(account: String, service: String) -> Data? {
        var query = baseQuery(account: account, service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        // Non-interactive legacy path
        let ctx = LAContext()
        ctx.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = ctx

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    // MARK: - Presence / delete

    static func exists(account: String, service: String = defaultService) -> Bool {
        var query = baseQuery(account: account, service: service)
        query[kSecReturnData as String] = false
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let ctx = LAContext()
        ctx.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = ctx
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
        var query = baseQuery(account: account, service: service)
        withAuthContext(&query)
        SecItemDelete(query as CFDictionary)
        SecItemDelete(baseQuery(account: account, service: service) as CFDictionary)
    }
}

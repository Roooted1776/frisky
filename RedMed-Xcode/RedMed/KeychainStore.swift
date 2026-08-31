import Foundation
import LocalAuthentication
import Security

/// Hardware-encrypted on-device storage for the RedMed profile blob.
///
/// **Current contract:** `kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly`
/// with **no** `kSecAttrAccessControl`. Readable whenever this device is
/// unlocked. Excluded from iCloud Keychain and encrypted backups
/// (`kSecAttrSynchronizable = false`). Face ID is **UI-only** on owner
/// Edit / Save / Erase (`BiometricAuth`) — not a SecItem ACL. Viewing the
/// card, 911, Aid, NFC write, app launch, and tapper do not prompt.
///
/// **Legacy items:** `biometryCurrentSet` ACL (older builds) or plain
/// accessibility with no ACL. `load` still reads them. A successful read
/// then **migrates** to the unbound-when-unlocked form (best-effort).
/// Never write a new `biometryCurrentSet` item.
///
/// `load` / `save` may still attach `BiometricAuth.peekAuthenticationContext()`
/// so a just-completed Edit/Save Face ID can update or replace an old
/// biometry row without a second sheet.
enum KeychainStore {
    private static let defaultService = "com.redmed.app.profile"

    private static func baseQuery(account: String, service: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
    }

    /// Attach parked LAContext so a leftover biometry ACL row can update/delete
    /// without a second prompt after Edit/Save Face ID.
    private static func withAuthContext(_ query: inout [String: Any], extra: LAContext? = nil) {
        if let ctx = extra ?? BiometricAuth.peekAuthenticationContext() {
            ctx.interactionNotAllowed = extra == nil
            query[kSecUseAuthenticationContext as String] = ctx
        }
    }

    // MARK: - Save

    /// Writes an unbound WhenPasscodeSetThisDeviceOnly item. Never stores a
    /// new biometryCurrentSet ACL. Returns false instead of dropping the blob.
    @discardableResult
    static func save(_ data: Data, account: String, service: String = defaultService) -> Bool {
        migrateUnlocked(data, account: account, service: service, authContext: BiometricAuth.peekAuthenticationContext())
    }

    /// Staging account used only while replacing an existing row (old ACL →
    /// unbound). `load` falls back here if the process dies between delete and re-add.
    private static func stagingAccount(_ account: String) -> String {
        account + ".migrating"
    }

    private static func addUnlocked(
        _ data: Data,
        account: String,
        service: String
    ) -> Bool {
        var add = baseQuery(account: account, service: service)
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        // Never set kSecAttrAccessControl — Face ID is UI-only, not SecItem.
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    /// Add the new unbound item first, then delete the old row. Kill/crash
    /// between those steps leaves PHI on the staging account, which `load`
    /// still reads. Returns true only when the canonical account holds the blob.
    private static func replaceViaStaging(
        _ data: Data,
        account: String,
        service: String,
        authContext: LAContext?
    ) -> Bool {
        let staging = stagingAccount(account)
        delete(account: staging, service: service)
        guard addUnlocked(data, account: staging, service: service) else {
            return false
        }
        delete(account: account, service: service, authContext: authContext)
        if addUnlocked(data, account: account, service: service) {
            delete(account: staging, service: service)
            return true
        }
        // One retry — transient SecItemAdd after delete.
        if addUnlocked(data, account: account, service: service) {
            delete(account: staging, service: service)
            return true
        }
        // Canonical account empty; staging still has PHI for the next `load`.
        // Fail the save so Edit does not report OK.
        return false
    }

    /// Update in place with the new accessibility; on an old biometry ACL row
    /// (auth / interaction / attr errors) replace via staging with the unbound form.
    @discardableResult
    private static func migrateUnlocked(
        _ data: Data,
        account: String,
        service: String,
        authContext: LAContext?
    ) -> Bool {
        var query = baseQuery(account: account, service: service)
        withAuthContext(&query, extra: authContext)

        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }

        if updateStatus == errSecItemNotFound {
            return addUnlocked(data, account: account, service: service)
        }
        if updateStatus == errSecAuthFailed
            || updateStatus == errSecInteractionNotAllowed
            || updateStatus == errSecNoSuchAttr
            || updateStatus == errSecParam {
            return replaceViaStaging(data, account: account, service: service, authContext: authContext)
        }

        return false
    }

    // MARK: - Load

    static func load(
        account: String,
        service: String = defaultService,
        context: LAContext? = nil,
        allowInteractive: Bool = false,
        allowLegacy: Bool = true
    ) -> Data? {
        let parked = context ?? BiometricAuth.peekAuthenticationContext()
        // (a) Non-interactive — WhenPasscodeSet / WhenUnlocked items, and some legacy.
        if let data = loadNonInteractive(account: account, service: service, context: parked) {
            return data
        }
        // (b) Legacy plain-accessibility query (no parked context).
        if allowLegacy, let data = loadLegacy(account: account, service: service) {
            _ = save(data, account: account, service: service)
            return data
        }
        // (c) Staging leftover from a killed migrate.
        if let data = loadNonInteractive(
            account: stagingAccount(account),
            service: service,
            context: parked
        ) {
            _ = save(data, account: account, service: service)
            delete(account: stagingAccount(account), service: service)
            return data
        }
        // (d) One interactive load for old biometryCurrentSet items, then migrate
        // to the ACL-less WhenPasscodeSetThisDeviceOnly form.
        if allowInteractive {
            let ctx = LAContext()
            ctx.localizedReason = "Restore your RedMed medical ID."
            if let data = loadInteractive(account: account, service: service, context: ctx) {
                _ = migrateUnlocked(data, account: account, service: service, authContext: ctx)
                return data
            }
            if let data = loadInteractive(
                account: stagingAccount(account),
                service: service,
                context: ctx
            ) {
                _ = migrateUnlocked(data, account: account, service: service, authContext: ctx)
                delete(account: stagingAccount(account), service: service)
                return data
            }
        }
        return nil
    }

    private static func loadNonInteractive(
        account: String,
        service: String,
        context: LAContext?
    ) -> Data? {
        var query = baseQuery(account: account, service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        let ctx = context ?? LAContext()
        ctx.interactionNotAllowed = true
        query[kSecUseAuthenticationContext as String] = ctx
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func loadInteractive(
        account: String,
        service: String,
        context: LAContext
    ) -> Data? {
        var query = baseQuery(account: account, service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecUseAuthenticationContext as String] = context
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func loadLegacy(account: String, service: String) -> Data? {
        var query = baseQuery(account: account, service: service)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
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
            // Staging may hold the only copy mid-migrate.
            var q = baseQuery(account: stagingAccount(account), service: service)
            q[kSecReturnData as String] = false
            q[kSecMatchLimit as String] = kSecMatchLimitOne
            q[kSecUseAuthenticationContext as String] = ctx
            let staged = SecItemCopyMatching(q as CFDictionary, nil)
            return staged == errSecSuccess || staged == errSecInteractionNotAllowed || staged == errSecAuthFailed
        default:
            // Unknown SecItem error is not proof a blob exists. Fail closed
            // so the empty-profile funnel can show instead of a locked ghost.
            return false
        }
    }

    static func delete(account: String, service: String = defaultService, authContext: LAContext? = nil) {
        var query = baseQuery(account: account, service: service)
        withAuthContext(&query, extra: authContext)
        SecItemDelete(query as CFDictionary)
        SecItemDelete(baseQuery(account: account, service: service) as CFDictionary)
    }
}

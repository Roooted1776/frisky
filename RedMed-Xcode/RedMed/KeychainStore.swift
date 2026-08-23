import Foundation
import Security

/// Hardware-encrypted on-device storage for the RedMed profile blob.
/// `.whenPasscodeSetThisDeviceOnly` + non-synchronizable — never iCloud Keychain.
/// Requires a device passcode (standard on Face ID / Touch ID phones). Items do
/// not migrate to a new device and are unavailable if the passcode is removed.
enum KeychainStore {
    private static let defaultService = "com.redmed.app.profile"

    /// Preferred accessibility for new writes and migrated items.
    private static let preferredAccessibility = kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly

    /// Update-or-add. Never delete-then-add — a failed add after delete would wipe PHI.
    /// Always writes the preferred accessibility class.
    @discardableResult
    static func save(_ data: Data, account: String, service: String = defaultService) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any
        ]
        let update: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: preferredAccessibility
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if updateStatus == errSecSuccess {
            return true
        }
        guard updateStatus == errSecItemNotFound else {
            return false
        }

        var attributes = query
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = preferredAccessibility
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    static func load(account: String, service: String = defaultService) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }

        // Upgrade legacy WhenUnlockedThisDeviceOnly blobs to the passcode-bound class.
        // Best-effort; failure leaves the original item readable under its old class.
        _ = save(data, account: account, service: service)

        return data
    }

    /// Presence check only — no blob decode (cold-launch gate).
    static func exists(account: String, service: String = defaultService) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
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

import Foundation

/// On-device file vault for owner-local data that must not leave the phone.
///
/// Controls (HIPAA offline posture for RedMed as operator):
/// - `FileProtectionType.complete` — ciphertext only; unreadable while device locked
///   or when plugged into another computer without unlock.
/// - `URLResourceValues.isExcludedFromBackup = true` — never copied to consumer
///   iCloud / iTunes / Finder backups.
///
/// Profile PHI remains in Keychain (`WhenUnlockedThisDeviceOnly`). This vault holds
/// the local history / audit database and any future sandbox files that need the
/// same hardware protection + backup exclusion.
enum HIPAAOfflineVault {
    private static let folderName = "HIPAAOfflineVault"
    private static let protection: FileProtectionType = .complete

    /// Application Support / HIPAAOfflineVault — created on first use.
    /// No temporaryDirectory fallback (that path is not durable / weaker).
    static var rootDirectory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return base.appendingPathComponent(folderName, isDirectory: true)
    }

    /// Ensures the vault directory exists with complete protection and backup exclusion.
    @discardableResult
    static func prepare() -> URL? {
        guard let dir = rootDirectory else { return nil }
        let fm = FileManager.default
        if !fm.fileExists(atPath: dir.path) {
            do {
                try fm.createDirectory(
                    at: dir,
                    withIntermediateDirectories: true,
                    attributes: [.protectionKey: protection]
                )
            } catch {
                return nil
            }
        }
        harden(url: dir, isDirectory: true)
        return dir
    }

    /// Writes `data` under the vault with complete file protection + backup exclusion.
    static func write(_ data: Data, fileName: String) throws {
        guard let dir = prepare() else {
            throw VaultError.unavailable
        }
        let url = dir.appendingPathComponent(fileName, isDirectory: false)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        harden(url: url, isDirectory: false)
    }

    /// Reads a vault file, or `nil` if missing.
    static func read(fileName: String) -> Data? {
        guard let dir = prepare() else { return nil }
        let url = dir.appendingPathComponent(fileName, isDirectory: false)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Removes a vault file if present.
    static func remove(fileName: String) {
        guard let dir = rootDirectory else { return }
        let url = dir.appendingPathComponent(fileName, isDirectory: false)
        try? FileManager.default.removeItem(at: url)
    }

    enum VaultError: Error {
        case unavailable
    }

    /// Re-applies complete protection + backup exclusion (idempotent).
    private static func harden(url: URL, isDirectory: Bool) {
        try? FileManager.default.setAttributes(
            [.protectionKey: protection],
            ofItemAtPath: url.path
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = url
        try? mutable.setResourceValues(values)
        _ = isDirectory
    }
}

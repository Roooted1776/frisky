import Foundation

/// On-device file vault for owner-local data that must not leave the phone.
///
/// Controls (HIPAA offline posture for RedMed as operator):
/// - `FileProtectionType.complete` — ciphertext only; unreadable while device locked
///   or when plugged into another computer without unlock.
/// - `URLResourceValues.isExcludedFromBackup = true` — never copied to consumer
///   iCloud / iTunes / Finder backups.
///
/// Profile PHI remains in Keychain (`WhenPasscodeSetThisDeviceOnly` + `biometryCurrentSet`,
/// see `KeychainStore`). This vault holds
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
        do {
            try harden(url: dir, isDirectory: true)
        } catch {
            return nil
        }
        return dir
    }

    /// Writes `data` under the vault with complete file protection + backup exclusion.
    /// Deletes the file and throws if post-write hardening fails.
    static func write(_ data: Data, fileName: String) throws {
        guard let dir = prepare() else {
            throw VaultError.unavailable
        }
        let name = try validatedFileName(fileName)
        let url = dir.appendingPathComponent(name, isDirectory: false)
        // Refuse escapes even if Foundation normalizes oddly on some OS versions.
        guard url.standardizedFileURL.path.hasPrefix(dir.standardizedFileURL.path + "/") else {
            throw VaultError.invalidPath
        }
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        do {
            try harden(url: url, isDirectory: false)
            try verifyHardened(url: url)
        } catch {
            try? FileManager.default.removeItem(at: url)
            throw VaultError.hardenFailed
        }
    }

    /// Reads a vault file, or `nil` if missing.
    static func read(fileName: String) -> Data? {
        guard let dir = prepare(),
              let name = try? validatedFileName(fileName) else { return nil }
        let url = dir.appendingPathComponent(name, isDirectory: false)
        guard url.standardizedFileURL.path.hasPrefix(dir.standardizedFileURL.path + "/"),
              FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try? Data(contentsOf: url)
    }

    /// Removes a vault file if present.
    static func remove(fileName: String) {
        guard let dir = rootDirectory,
              let name = try? validatedFileName(fileName) else { return }
        let url = dir.appendingPathComponent(name, isDirectory: false)
        guard url.standardizedFileURL.path.hasPrefix(dir.standardizedFileURL.path + "/") else { return }
        try? FileManager.default.removeItem(at: url)
    }

    /// Deletes every file under the vault root (owner erase). Directory stays hardened.
    static func removeAll() {
        guard let dir = prepare() else { return }
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for url in items {
            guard url.standardizedFileURL.path.hasPrefix(dir.standardizedFileURL.path + "/") else { continue }
            try? fm.removeItem(at: url)
        }
    }

    enum VaultError: Error {
        case unavailable
        case hardenFailed
        case invalidPath
    }

    /// Basename only — reject `/`, `\`, and `..` so callers cannot escape the vault root.
    private static func validatedFileName(_ fileName: String) throws -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw VaultError.invalidPath }
        guard !trimmed.contains("/"),
              !trimmed.contains("\\"),
              trimmed != "." && trimmed != "..",
              !trimmed.contains("..") else {
            throw VaultError.invalidPath
        }
        let base = (trimmed as NSString).lastPathComponent
        guard base == trimmed else { throw VaultError.invalidPath }
        return base
    }

    /// Re-applies complete protection + backup exclusion (idempotent).
    private static func harden(url: URL, isDirectory: Bool) throws {
        try FileManager.default.setAttributes(
            [.protectionKey: protection],
            ofItemAtPath: url.path
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = url
        try mutable.setResourceValues(values)
        _ = isDirectory
    }

    private static func verifyHardened(url: URL) throws {
        // Backup exclusion is the durable check we can assert everywhere (incl. Simulator).
        // File protection is applied via write options + setAttributes; Simulator does not
        // reliably report protection attributes, so we do not gate on a re-read there.
        let values = try url.resourceValues(forKeys: [.isExcludedFromBackupKey])
        guard values.isExcludedFromBackup == true else {
            throw VaultError.hardenFailed
        }
    }
}

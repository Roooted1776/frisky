import Foundation
import Combine

/// Owner-only local history stored in `HIPAAOfflineVault`.
/// Events never contain field values (no name/meds/contacts) — timestamps + kind only.
/// Vault JSON is loaded on first `record` / `reload` — not at shared init / cold launch.
final class VaultHistoryStore: ObservableObject {
    static let shared = VaultHistoryStore()

    private static let fileName = "vault-history.v1.json"
    private static let maxEvents = 200

    @Published private(set) var events: [VaultHistoryEvent] = []
    private var didLoad = false

    private init() {}

    func reload() {
        didLoad = true
        guard let data = HIPAAOfflineVault.read(fileName: Self.fileName),
              let decoded = try? JSONDecoder().decode([VaultHistoryEvent].self, from: data) else {
            events = []
            return
        }
        events = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    func record(_ kind: VaultHistoryEvent.Kind, detail: String = "") {
        ensureLoaded()
        // Coalesce duplicate writes from paired NFC success/verified callbacks.
        if let newest = events.first,
           newest.kind == kind,
           newest.detail == detail,
           Date().timeIntervalSince(newest.createdAt) < 2 {
            return
        }
        var next = events
        next.insert(
            VaultHistoryEvent(id: UUID(), kind: kind, detail: detail, createdAt: Date()),
            at: 0
        )
        if next.count > Self.maxEvents {
            next = Array(next.prefix(Self.maxEvents))
        }
        events = next
        persist(next)
    }

    func clear() {
        didLoad = true
        events = []
        HIPAAOfflineVault.remove(fileName: Self.fileName)
    }

    /// Drop in-RAM events after UI lock — disk blob stays until Face ID reload.
    func purgeFromMemory() {
        events = []
        didLoad = false
    }

    private func ensureLoaded() {
        if !didLoad { reload() }
    }

    private func persist(_ events: [VaultHistoryEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        try? HIPAAOfflineVault.write(data, fileName: Self.fileName)
    }
}

struct VaultHistoryEvent: Identifiable, Codable, Equatable {
    enum Kind: String, Codable {
        case profileSaved
        case braceletWritten
        case vaultCleared
        /// Face ID / passcode mismatch (not cancel). `detail` = gate id only.
        case unlockFailed
        /// NFC write ended without success (not cancel). Status strings only in `detail`.
        case nfcWriteFailed
        /// Screen capture / mirroring while PHI was in RAM.
        case screenCaptureCovered

        var title: String {
            switch self {
            case .profileSaved: return "Profile saved"
            case .braceletWritten: return "Bracelet written"
            case .vaultCleared: return "History cleared"
            case .unlockFailed: return "Unlock failed"
            case .nfcWriteFailed: return "NFC write failed"
            case .screenCaptureCovered: return "Screen capture covered"
            }
        }

        var systemImage: String {
            switch self {
            case .profileSaved: return "person.text.rectangle"
            case .braceletWritten: return "wave.3.right"
            case .vaultCleared: return "trash"
            case .unlockFailed: return "lock.slash"
            case .nfcWriteFailed: return "wave.3.right.circle"
            case .screenCaptureCovered: return "eye.slash"
            }
        }
    }

    var id: UUID
    var kind: Kind
    var detail: String
    var createdAt: Date
}

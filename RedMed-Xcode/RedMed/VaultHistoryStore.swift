import Foundation
import Combine

/// Owner-only local history stored in `HIPAAOfflineVault`.
/// Events never contain field values (no name/meds/contacts) — timestamps + kind only.
final class VaultHistoryStore: ObservableObject {
    static let shared = VaultHistoryStore()

    private static let fileName = "vault-history.v1.json"
    private static let maxEvents = 200

    @Published private(set) var events: [VaultHistoryEvent] = []

    private init() {
        reload()
    }

    func reload() {
        guard let data = HIPAAOfflineVault.read(fileName: Self.fileName),
              let decoded = try? JSONDecoder().decode([VaultHistoryEvent].self, from: data) else {
            events = []
            return
        }
        events = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    func record(_ kind: VaultHistoryEvent.Kind, detail: String = "") {
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
        events = []
        HIPAAOfflineVault.remove(fileName: Self.fileName)
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

        var title: String {
            switch self {
            case .profileSaved: return "Profile saved"
            case .braceletWritten: return "Bracelet written"
            case .vaultCleared: return "History cleared"
            }
        }

        var systemImage: String {
            switch self {
            case .profileSaved: return "person.text.rectangle"
            case .braceletWritten: return "wave.3.right"
            case .vaultCleared: return "trash"
            }
        }
    }

    var id: UUID
    var kind: Kind
    var detail: String
    var createdAt: Date
}

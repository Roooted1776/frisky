import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published var profile: MedicalProfile {
        didSet { save() }
    }

    private static let account = "medicalProfile.v1"

    init() {
        if let data = KeychainStore.load(account: Self.account),
           let decoded = try? JSONDecoder().decode(MedicalProfile.self, from: data) {
            profile = decoded
        } else {
            profile = MedicalProfile()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(profile) {
            KeychainStore.save(data, account: Self.account)
        }
    }

    /// Wipes the saved profile from the Keychain. Does not affect an
    /// already-written NFC tag until the next save with a linked bracelet.
    func clearAllData() {
        KeychainStore.delete(account: Self.account)
        profile = MedicalProfile()
    }
}

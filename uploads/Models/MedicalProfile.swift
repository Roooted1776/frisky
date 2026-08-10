import Foundation

/// Medical profile fields written to the band chip (`#d=` JSON): name, dob,
/// blood, donor, allergies, meds, conditions, contacts, updated.

struct EmergencyContact: Codable, Identifiable, Equatable, Hashable {
    var id = UUID()
    var name: String = ""
    var rel: String = ""
    var phone: String = ""

    enum CodingKeys: String, CodingKey {
        case name, rel, phone
    }
}

struct MedicalProfile: Codable, Equatable, Hashable {
    var name: String = ""
    var dob: String = ""
    var blood: String = ""
    var donor: Bool = false
    var allergies: [String] = []
    var meds: [String] = []
    var conditions: [String] = []
    var contacts: [EmergencyContact] = []
    var updated: String = ""

    /// True once the owner has saved any medical ID on this device. Drives
    /// edit auth — first-time setup stays open until Save.
    var hasOwnerData: Bool {
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return true }
        if !dob.isEmpty || !blood.isEmpty { return true }
        if !allergies.isEmpty || !meds.isEmpty || !conditions.isEmpty { return true }
        if contacts.contains(where: {
            !$0.name.trimmingCharacters(in: .whitespaces).isEmpty
                || !$0.phone.trimmingCharacters(in: .whitespaces).isEmpty
                || !$0.rel.trimmingCharacters(in: .whitespaces).isEmpty
        }) { return true }
        return false
    }
}

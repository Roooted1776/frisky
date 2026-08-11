import Foundation

/// On-chip `#d=` JSON shape — must stay compatible with the hosted card page
/// and the uploads RedMed profile encoder.
struct NFCChipProfile: Codable, Equatable {
    var name: String = ""
    var dob: String = ""
    var blood: String = ""
    var donor: Bool = false
    var allergies: [String] = []
    var meds: [String] = []
    var conditions: [String] = []
    var contacts: [NFCChipContact] = []
    var updated: String = ""
}

struct NFCChipContact: Codable, Equatable {
    var name: String = ""
    var rel: String = ""
    var phone: String = ""
}

enum ProfileNFCCodec {
    private static let maxEncodedLength = 8192

    static func chipProfile(from profile: ProfileData) -> NFCChipProfile {
        NFCChipProfile(
            name: profile.name,
            dob: profile.birthDate,
            blood: profile.bloodType,
            donor: profile.isOrganDonor,
            allergies: profile.allergies,
            meds: profile.medications,
            conditions: profile.conditions,
            contacts: profile.contacts.map { contact in
                NFCChipContact(
                    name: contact.name,
                    rel: contact.relationship,
                    phone: contact.dialDigits.isEmpty ? contact.phone : contact.dialDigits
                )
            },
            updated: profile.lastUpdated
        )
    }

    static func apply(_ chip: NFCChipProfile, to profile: ProfileData) {
        profile.name = chip.name
        profile.birthDate = chip.dob
        profile.bloodType = chip.blood
        profile.isOrganDonor = chip.donor
        profile.allergies = chip.allergies
        profile.medications = chip.meds
        profile.conditions = chip.conditions
        profile.contacts = chip.contacts.map { c in
            EmergencyContact(name: c.name, relationship: c.rel, phone: c.phone)
        }
        if !chip.updated.isEmpty {
            profile.lastUpdated = chip.updated
        }
    }

    /// Full NDEF URI string including `#d=` — prefer this over `URL` when writing tags
    /// so the fragment is never dropped by URL parsing.
    static func buildURLString(profile: ProfileData, baseURL: String = AppConfig.medicalCardBaseURL) -> String? {
        var chip = chipProfile(from: profile)
        chip.updated = ISO8601DateFormatter().string(from: Date())
        guard let jsonData = try? JSONEncoder().encode(chip) else { return nil }
        let encoded = base64url(jsonData)
        guard !encoded.isEmpty else { return nil }
        return baseURL + "#d=" + encoded
    }

    static func buildURL(profile: ProfileData, baseURL: String = AppConfig.medicalCardBaseURL) -> URL? {
        guard let s = buildURLString(profile: profile, baseURL: baseURL) else { return nil }
        return URL(string: s)
    }

    static func decodeProfile(fromURLString urlString: String) -> NFCChipProfile? {
        guard let range = urlString.range(of: "#d=") else { return nil }
        let encoded = String(urlString[range.upperBound...])
        guard encoded.utf8.count <= maxEncodedLength else { return nil }
        guard let data = base64urlDecode(encoded), data.count <= maxEncodedLength else { return nil }
        return try? JSONDecoder().decode(NFCChipProfile.self, from: data)
    }

    static func capacityNote(for profile: ProfileData) -> (text: String, warn: Bool) {
        guard let jsonData = try? JSONEncoder().encode(chipProfile(from: profile)) else {
            return ("Tag capacity unknown", false)
        }
        let encoded = base64url(jsonData)
        let byteCount = (AppConfig.medicalCardBaseURL + "#d=" + encoded).utf8.count
        if byteCount > 850 {
            return ("\(byteCount) bytes on tag — too large for most NFC tags. Shorten entries or use NTAG216.", true)
        } else if byteCount > 480 {
            return ("\(byteCount) bytes on tag — needs an NTAG216", false)
        } else if byteCount > 140 {
            return ("\(byteCount) bytes on tag — needs NTAG215 or NTAG216", false)
        } else {
            return ("\(byteCount) bytes on tag — fits NTAG213+", false)
        }
    }

    private static func base64url(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64urlDecode(_ encoded: String) -> Data? {
        var base64 = encoded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: base64)
    }
}

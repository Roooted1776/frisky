import CryptoKit
import Foundation

/// On-chip profile after decode — must stay compatible with the hosted card page
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

/// NFC `#d=` codec: minify → AES-GCM → URL-safe Base64 on a short HTTPS get URL.
///
/// Wire format (new writes):
/// 1. Profile → flat positional array (no JSON keys):
///    `[blood, allergies, meds, emergencyPhone, name, dob, conditions, contacts, donor, updated?]`
///    Indices 0–3 match the product compact schema; 4+ keep the full card usable.
///    List fields are comma-joined strings; contacts are `[name, rel, phone]` rows.
/// 2. UTF-8 JSON array (no spaces) sealed with AES-GCM (CryptoKit).
/// 3. Bytes `0x02 || nonce(12) || ciphertext+tag` → base64url after `#d=`.
///
/// The AES key is a public client constant (SHA-256 of a fixed label), also
/// embedded in `get.html`. This is packing/obfuscation so the fragment is not
/// casual plaintext JSON — any phone that loads get.html can decrypt. EMS must
/// read the band with no account; a private key would defeat the product.
/// Legacy `#d=` base64url JSON objects still decode.
enum ProfileNFCCodec {
    private static let maxEncodedLength = 8192
    /// Version byte for AES-GCM sealed payloads.
    private static let aesVersion: UInt8 = 0x02
    /// Shared with `get.html` — derive AES-256 key via SHA-256.
    private static let keyLabel = "RedMed-NFC-AES-GCM-v1"

    /// Compact array indexes (must match get.html).
    private enum Idx {
        static let blood = 0
        static let allergies = 1
        static let meds = 2
        static let emergencyPhone = 3
        static let name = 4
        static let dob = 5
        static let conditions = 6
        static let contacts = 7
        static let donor = 8
        static let updated = 9
    }

    private static var aesKey: SymmetricKey {
        SymmetricKey(data: Data(SHA256.hash(data: Data(keyLabel.utf8))))
    }

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
        guard let encoded = encodePayload(chip) else { return nil }
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
        return decodePayload(encoded)
    }

    static func capacityNote(for profile: ProfileData) -> (text: String, warn: Bool) {
        guard let url = buildURLString(profile: profile) else {
            return ("Tag capacity unknown", true)
        }
        let byteCount = url.utf8.count
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

    // MARK: - Encode / decode

    private static func encodePayload(_ chip: NFCChipProfile) -> String? {
        let compact = compactArray(from: chip)
        guard JSONSerialization.isValidJSONObject(compact),
              let jsonData = try? JSONSerialization.data(withJSONObject: compact, options: []) else {
            return nil
        }
        guard let sealed = try? AES.GCM.seal(jsonData, using: aesKey),
              let combined = sealed.combined else {
            return nil
        }
        var payload = Data([aesVersion])
        payload.append(combined)
        let encoded = base64url(payload)
        guard !encoded.isEmpty, encoded.utf8.count <= maxEncodedLength else { return nil }
        return encoded
    }

    private static func decodePayload(_ encoded: String) -> NFCChipProfile? {
        guard let data = base64urlDecode(encoded), data.count <= maxEncodedLength, !data.isEmpty else {
            return nil
        }
        if data[data.startIndex] == aesVersion {
            let sealedData = data.dropFirst()
            guard sealedData.count > 12 + 16,
                  let box = try? AES.GCM.SealedBox(combined: Data(sealedData)),
                  let plain = try? AES.GCM.open(box, using: aesKey),
                  let json = tryUTF8JSON(plain) else {
                return nil
            }
            return profile(fromJSON: json)
        }
        // Legacy plaintext base64url JSON (object or compact array).
        guard let json = tryUTF8JSON(data) else { return nil }
        return profile(fromJSON: json)
    }

    private static func compactArray(from chip: NFCChipProfile) -> [Any] {
        let phone = chip.contacts.first.flatMap { c -> String? in
            let digits = c.phone.filter { $0.isNumber || $0 == "+" }
            return digits.isEmpty ? nil : digits
        } ?? ""
        var row: [Any] = [
            chip.blood,
            joinList(chip.allergies),
            joinList(chip.meds),
            phone,
            chip.name,
            chip.dob,
            joinList(chip.conditions),
            chip.contacts.map { [$0.name, $0.rel, $0.phone] as [Any] },
            chip.donor ? 1 : 0
        ]
        if !chip.updated.isEmpty {
            row.append(chip.updated)
        }
        return row
    }

    private static func profile(fromJSON json: Any) -> NFCChipProfile? {
        if let arr = json as? [Any] {
            return profile(fromArray: arr)
        }
        if let obj = json as? [String: Any] {
            return profile(fromObject: obj)
        }
        return nil
    }

    private static func profile(fromArray arr: [Any]) -> NFCChipProfile {
        func str(_ i: Int) -> String {
            guard i < arr.count else { return "" }
            if let s = arr[i] as? String { return s }
            if let n = arr[i] as? NSNumber { return n.stringValue }
            return ""
        }
        func list(_ i: Int) -> [String] {
            guard i < arr.count else { return [] }
            if let a = arr[i] as? [Any] {
                return a.compactMap { $0 as? String }.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            }
            return splitList(str(i))
        }
        func contacts(_ i: Int) -> [NFCChipContact] {
            guard i < arr.count, let rows = arr[i] as? [Any] else { return [] }
            return rows.compactMap { row in
                guard let parts = row as? [Any] else { return nil }
                func part(_ j: Int) -> String {
                    guard j < parts.count else { return "" }
                    if let s = parts[j] as? String { return s }
                    if let n = parts[j] as? NSNumber { return n.stringValue }
                    return ""
                }
                let c = NFCChipContact(name: part(0), rel: part(1), phone: part(2))
                if c.name.isEmpty && c.rel.isEmpty && c.phone.isEmpty { return nil }
                return c
            }
        }
        func donorFlag(_ i: Int) -> Bool {
            guard i < arr.count else { return false }
            if let b = arr[i] as? Bool { return b }
            if let n = arr[i] as? NSNumber { return n.intValue != 0 }
            if let s = arr[i] as? String { return s == "1" || s.lowercased() == "true" }
            return false
        }

        var chip = NFCChipProfile(
            name: str(Idx.name),
            dob: str(Idx.dob),
            blood: str(Idx.blood),
            donor: donorFlag(Idx.donor),
            allergies: list(Idx.allergies),
            meds: list(Idx.meds),
            conditions: list(Idx.conditions),
            contacts: contacts(Idx.contacts),
            updated: str(Idx.updated)
        )
        let emergency = str(Idx.emergencyPhone)
        if !emergency.isEmpty {
            if chip.contacts.isEmpty {
                chip.contacts = [NFCChipContact(name: "Emergency", rel: "", phone: emergency)]
            } else if chip.contacts[0].phone.isEmpty {
                chip.contacts[0].phone = emergency
            }
        }
        return chip
    }

    private static func profile(fromObject obj: [String: Any]) -> NFCChipProfile {
        func str(_ key: String) -> String {
            if let s = obj[key] as? String { return s }
            if let n = obj[key] as? NSNumber { return n.stringValue }
            return ""
        }
        func list(_ key: String) -> [String] {
            if let a = obj[key] as? [Any] {
                return a.compactMap { $0 as? String }
            }
            return splitList(str(key))
        }
        let contactRows: [NFCChipContact]
        if let raw = obj["contacts"] as? [Any] {
            contactRows = raw.compactMap { row in
                guard let c = row as? [String: Any] else { return nil }
                return NFCChipContact(
                    name: (c["name"] as? String) ?? "",
                    rel: (c["rel"] as? String) ?? "",
                    phone: (c["phone"] as? String) ?? ""
                )
            }
        } else {
            contactRows = []
        }
        let donor: Bool
        if let b = obj["donor"] as? Bool {
            donor = b
        } else if let n = obj["donor"] as? NSNumber {
            donor = n.boolValue
        } else {
            donor = false
        }
        return NFCChipProfile(
            name: str("name"),
            dob: str("dob"),
            blood: str("blood"),
            donor: donor,
            allergies: list("allergies"),
            meds: list("meds"),
            conditions: list("conditions"),
            contacts: contactRows,
            updated: str("updated")
        )
    }

    private static func joinList(_ items: [String]) -> String {
        items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private static func splitList(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func tryUTF8JSON(_ data: Data) -> Any? {
        guard let obj = try? JSONSerialization.jsonObject(with: data, options: []) else { return nil }
        return obj
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

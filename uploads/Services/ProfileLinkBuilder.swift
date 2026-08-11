import CryptoKit
import Foundation

/// Builds the on-chip NDEF URI: flat array → AES-GCM → base64url after `#d=`.
/// Matches `ProfileNFCCodec` / `get.html`. New writes use
/// `AppConfig.medicalCardBaseURL`. Legacy plaintext JSON still decodes.
enum ProfileLinkBuilder {

    private static let maxEncodedLength = 8192
    private static let maxName = 120
    private static let maxDob = 32
    private static let maxBlood = 16
    private static let maxUpdated = 40
    private static let maxListItem = 80
    private static let maxListCount = 32
    private static let maxContacts = 4
    private static let maxContactField = 160

    private static let aesVersion: UInt8 = 0x02
    private static let keyLabel = "RedMed-NFC-AES-GCM-v1"

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

    static func buildURL(profile: MedicalProfile, baseURL: String) -> URL? {
        var stamped = profile
        stamped.updated = ISO8601DateFormatter().string(from: Date())
        guard let encoded = encodePayload(stamped) else { return nil }
        return URL(string: baseURL + "#d=" + encoded)
    }

    static func previewURL(profile: MedicalProfile) -> URL? {
        buildURL(profile: profile, baseURL: AppConfig.medicalCardBaseURL)
    }

    static func capacityNote(
        for profile: MedicalProfile,
        baseURL: String = AppConfig.medicalCardBaseURL
    ) -> (text: String, warn: Bool) {
        guard let url = buildURL(profile: profile, baseURL: baseURL) else {
            return ("", true)
        }
        let byteCount = url.absoluteString.utf8.count

        if byteCount > 850 {
            return ("\(byteCount) bytes on tag — too large for most NFC tags. Shorten your entries or use an NTAG216 (~888 bytes).", true)
        } else if byteCount > 480 {
            return ("\(byteCount) bytes on tag — needs an NTAG216.", false)
        } else if byteCount > 140 {
            return ("\(byteCount) bytes on tag — needs an NTAG215 or NTAG216.", false)
        } else {
            return ("\(byteCount) bytes on tag — fits any standard NFC tag (NTAG213+).", false)
        }
    }

    static func decodeProfile(fromURLString urlString: String) -> MedicalProfile? {
        guard let range = urlString.range(of: "#d=") else { return nil }
        let encoded = String(urlString[range.upperBound...])
        guard encoded.utf8.count <= maxEncodedLength else { return nil }
        guard let profile = decodePayload(encoded) else { return nil }
        return clamp(profile)
    }

    // MARK: - Wire format

    private static func encodePayload(_ profile: MedicalProfile) -> String? {
        let compact = compactArray(from: profile)
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

    private static func decodePayload(_ encoded: String) -> MedicalProfile? {
        guard let data = base64urlDecode(encoded), data.count <= maxEncodedLength, !data.isEmpty else {
            return nil
        }
        if data[data.startIndex] == aesVersion {
            let sealedData = data.dropFirst()
            guard sealedData.count > 12 + 16,
                  let box = try? AES.GCM.SealedBox(combined: Data(sealedData)),
                  let plain = try? AES.GCM.open(box, using: aesKey),
                  let json = try? JSONSerialization.jsonObject(with: plain) else {
                return nil
            }
            return profile(fromJSON: json)
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return nil }
        return profile(fromJSON: json)
    }

    private static func compactArray(from profile: MedicalProfile) -> [Any] {
        let phone = profile.contacts.first.flatMap { c -> String? in
            let digits = c.phone.filter { $0.isNumber || $0 == "+" }
            return digits.isEmpty ? nil : digits
        } ?? ""
        var row: [Any] = [
            profile.blood,
            joinList(profile.allergies),
            joinList(profile.meds),
            phone,
            profile.name,
            profile.dob,
            joinList(profile.conditions),
            profile.contacts.map { [$0.name, $0.rel, $0.phone] as [Any] },
            profile.donor ? 1 : 0
        ]
        if !profile.updated.isEmpty {
            row.append(profile.updated)
        }
        return row
    }

    private static func profile(fromJSON json: Any) -> MedicalProfile? {
        if let arr = json as? [Any] { return profile(fromArray: arr) }
        if let obj = json as? [String: Any] { return profile(fromObject: obj) }
        return nil
    }

    private static func profile(fromArray arr: [Any]) -> MedicalProfile {
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
        func contacts(_ i: Int) -> [EmergencyContact] {
            guard i < arr.count, let rows = arr[i] as? [Any] else { return [] }
            return rows.compactMap { row in
                guard let parts = row as? [Any] else { return nil }
                func part(_ j: Int) -> String {
                    guard j < parts.count else { return "" }
                    if let s = parts[j] as? String { return s }
                    if let n = parts[j] as? NSNumber { return n.stringValue }
                    return ""
                }
                var c = EmergencyContact(name: part(0), rel: part(1), phone: part(2))
                if c.name.isEmpty && c.rel.isEmpty && c.phone.isEmpty { return nil }
                return c
            }
        }
        func donorFlag(_ i: Int) -> Bool {
            guard i < arr.count else { return false }
            if let b = arr[i] as? Bool { return b }
            if let n = arr[i] as? NSNumber { return n.intValue != 0 }
            return false
        }

        var p = MedicalProfile(
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
            if p.contacts.isEmpty {
                p.contacts = [EmergencyContact(name: "Emergency", rel: "", phone: emergency)]
            } else if p.contacts[0].phone.isEmpty {
                p.contacts[0].phone = emergency
            }
        }
        return p
    }

    private static func profile(fromObject obj: [String: Any]) -> MedicalProfile? {
        guard let data = try? JSONSerialization.data(withJSONObject: obj),
              let decoded = try? JSONDecoder().decode(MedicalProfile.self, from: data) else {
            return nil
        }
        return decoded
    }

    private static func joinList(_ items: [String]) -> String {
        items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }.joined(separator: ", ")
    }

    private static func splitList(_ raw: String) -> [String] {
        raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    private static func clamp(_ profile: MedicalProfile) -> MedicalProfile {
        var p = profile
        p.name = String(p.name.prefix(maxName))
        p.dob = String(p.dob.prefix(maxDob))
        p.blood = String(p.blood.prefix(maxBlood))
        p.updated = String(p.updated.prefix(maxUpdated))
        p.allergies = Array(p.allergies.map { String($0.prefix(maxListItem)) }.prefix(maxListCount))
        p.meds = Array(p.meds.map { String($0.prefix(maxListItem)) }.prefix(maxListCount))
        p.conditions = Array(p.conditions.map { String($0.prefix(maxListItem)) }.prefix(maxListCount))
        p.contacts = Array(p.contacts.prefix(maxContacts).map { c in
            var contact = c
            contact.name = String(contact.name.prefix(maxContactField))
            contact.rel = String(contact.rel.prefix(maxContactField))
            contact.phone = String(contact.phone.prefix(32))
            return contact
        })
        return p
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

import CryptoKit
import Foundation

/// Builds the on-chip NDEF URI: flat array → AES-GCM → base64url after `#d=`.
/// Matches `ProfileNFCCodec` / `get.html`. New writes use
/// `AppConfig.medicalCardBaseURL`. Legacy plaintext JSON, pre-AES compact
/// arrays, and `0x01` zlib wrappers still decode.
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

    private static let zlibVersion: UInt8 = 0x01
    private static let aesVersion: UInt8 = 0x02
    private static let keyLabel = "RedMed-NFC-AES-GCM-v1"
    private static let bloodTypes = ["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"]

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

    private enum LegacyIdx {
        static let name = 0
        static let dob = 1
        static let blood = 2
        static let donor = 3
        static let allergies = 4
        static let meds = 5
        static let conditions = 6
        static let contacts = 7
        static let updated = 8
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
                  let json = tryUTF8JSON(plain) else {
                return nil
            }
            return profile(fromJSON: json)
        }
        if let json = tryUTF8JSON(data) {
            return profile(fromJSON: json)
        }
        if data[data.startIndex] == zlibVersion,
           let inflated = zlibDecompress(data.dropFirst()),
           let json = tryUTF8JSON(inflated) {
            return profile(fromJSON: json)
        }
        if let inflated = zlibDecompress(data), let json = tryUTF8JSON(inflated) {
            return profile(fromJSON: json)
        }
        return nil
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

    private static func isLegacyCompactArray(_ arr: [Any]) -> Bool {
        if arr.count >= 9, isDonorFlag(arr[8]) { return false }
        guard arr.count >= 4 else { return false }
        let donorLike = isDonorFlag(arr[3])
        if donorLike && arr.count > LegacyIdx.allergies && arr[LegacyIdx.allergies] is [Any] {
            return true
        }
        if donorLike, let n = arr[LegacyIdx.blood] as? NSNumber, (0...7).contains(n.intValue) {
            return true
        }
        if donorLike,
           let name = arr[LegacyIdx.name] as? String,
           !bloodTypes.contains(name),
           looksLikeDob(arr[LegacyIdx.dob]),
           arr.count <= 9 {
            return true
        }
        return false
    }

    private static func isDonorFlag(_ value: Any) -> Bool {
        if value is Bool { return true }
        if let n = value as? NSNumber { return n.intValue == 0 || n.intValue == 1 }
        if let s = value as? String { return s == "0" || s == "1" }
        return false
    }

    private static func looksLikeDob(_ value: Any) -> Bool {
        guard let s = value as? String else { return value is NSNumber }
        let digits = s.filter(\.isNumber)
        return digits.count == 6 || digits.count == 8 || s.contains("-")
    }

    private static func profile(fromArray arr: [Any]) -> MedicalProfile {
        if isLegacyCompactArray(arr) {
            return profile(fromLegacyArray: arr)
        }
        return profile(fromCurrentArray: arr)
    }

    private static func profile(fromCurrentArray arr: [Any]) -> MedicalProfile {
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
            blood: expandBlood(arr.indices.contains(Idx.blood) ? arr[Idx.blood] : ""),
            donor: donorFlag(Idx.donor),
            allergies: list(Idx.allergies),
            meds: list(Idx.meds),
            conditions: list(Idx.conditions),
            contacts: contacts(Idx.contacts),
            updated: str(Idx.updated)
        )
        let emergency = usableEmergencyPhone(str(Idx.emergencyPhone))
        if !emergency.isEmpty {
            if p.contacts.isEmpty {
                p.contacts = [EmergencyContact(name: "Emergency", rel: "", phone: emergency)]
            } else if p.contacts[0].phone.isEmpty {
                p.contacts[0].phone = emergency
            }
        }
        return p
    }

    private static func profile(fromLegacyArray arr: [Any]) -> MedicalProfile {
        func str(_ i: Int) -> String {
            guard i < arr.count else { return "" }
            if let s = arr[i] as? String { return s }
            if let n = arr[i] as? NSNumber { return n.stringValue }
            return ""
        }
        func strs(_ i: Int) -> [String] {
            guard i < arr.count else { return [] }
            if let a = arr[i] as? [Any] {
                return a.compactMap { $0 as? String }
            }
            return splitList(str(i))
        }
        let donor: Bool = {
            guard LegacyIdx.donor < arr.count else { return false }
            if let b = arr[LegacyIdx.donor] as? Bool { return b }
            if let n = arr[LegacyIdx.donor] as? NSNumber { return n.intValue != 0 }
            return false
        }()
        let contacts: [EmergencyContact] = {
            guard LegacyIdx.contacts < arr.count, let rows = arr[LegacyIdx.contacts] as? [Any] else {
                return []
            }
            return rows.compactMap { row -> EmergencyContact? in
                guard let parts = row as? [Any] else { return nil }
                let name = parts.indices.contains(0) ? (parts[0] as? String ?? "") : ""
                let rel = parts.indices.contains(1) ? (parts[1] as? String ?? "") : ""
                let phone = parts.indices.contains(2) ? (parts[2] as? String ?? "") : ""
                if name.isEmpty && rel.isEmpty && phone.isEmpty { return nil }
                return EmergencyContact(name: name, rel: rel, phone: phone)
            }
        }()
        return MedicalProfile(
            name: str(LegacyIdx.name),
            dob: expandDob(str(LegacyIdx.dob)),
            blood: expandBlood(arr.indices.contains(LegacyIdx.blood) ? arr[LegacyIdx.blood] : ""),
            donor: donor,
            allergies: strs(LegacyIdx.allergies),
            meds: strs(LegacyIdx.meds),
            conditions: strs(LegacyIdx.conditions),
            contacts: contacts,
            updated: expandUpdated(str(LegacyIdx.updated))
        )
    }

    private static func usableEmergencyPhone(_ raw: String) -> String {
        let digits = raw.filter { $0.isNumber || $0 == "+" }
        return digits.filter(\.isNumber).count >= 3 ? digits : ""
    }

    private static func expandBlood(_ value: Any) -> String {
        if let i = value as? Int, bloodTypes.indices.contains(i) { return bloodTypes[i] }
        if let n = value as? NSNumber, bloodTypes.indices.contains(n.intValue) {
            return bloodTypes[n.intValue]
        }
        return value as? String ?? ""
    }

    private static func expandDob(_ dob: String) -> String {
        let digits = dob.filter(\.isNumber)
        if digits.count == 6 {
            let yy = Int(digits.prefix(2)) ?? 0
            let century = yy >= 70 ? "19" : "20"
            let s = century + digits
            return "\(s.prefix(4))-\(s.dropFirst(4).prefix(2))-\(s.suffix(2))"
        }
        if digits.count == 8 {
            return "\(digits.prefix(4))-\(digits.dropFirst(4).prefix(2))-\(digits.suffix(2))"
        }
        return dob
    }

    private static func expandUpdated(_ updated: String) -> String {
        let digits = updated.filter(\.isNumber)
        if digits.count == 6 {
            let yy = Int(digits.prefix(2)) ?? 0
            let century = yy >= 70 ? "19" : "20"
            return "\(century)\(digits.prefix(2))-\(digits.dropFirst(2).prefix(2))-\(digits.suffix(2))"
        }
        return updated
    }

    private static func tryUTF8JSON(_ data: Data) -> Any? {
        guard let first = data.first, first == UInt8(ascii: "{") || first == UInt8(ascii: "[") else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data, options: [])
    }

    private static func zlibDecompress(_ data: Data) -> Data? {
        do {
            let out: NSData = try (data as NSData).decompressed(using: .zlib)
            return out as Data
        } catch {
            return nil
        }
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

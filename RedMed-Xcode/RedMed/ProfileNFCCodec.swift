import Foundation

/// On-chip `#d=` shape — must stay compatible with `get.html` and uploads encoders.
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

/// Compact NDEF `#d=` codec for NTAG213 (~144 B user) serverless browser fallback.
///
/// New writes:
/// 1. Positional array indexes (not JSON keys):
///    `[name, dob, blood, donor, allergies, meds, conditions, contacts, updated?]`
///    contacts = `[name, rel, phone]`; blood may be 0…7.
/// 2. UTF-8 JSON. If zlib is smaller → `0x01` + zlib; else raw JSON.
/// 3. Base64url into short `…/get/#d=…`.
///
/// Legacy named JSON objects still decode. Packed/encoded, not ciphertext.
enum ProfileNFCCodec {
    private static let maxEncodedLength = 8192
    private static let ntag213URIBudget = 137
    private static let bloodTypes = ["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"]

    private enum Idx {
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
        chip.updated = compactUpdated(Date())
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
        let byteCount = ndefURIBody(from: url).utf8.count
        if byteCount > 850 {
            return ("\(byteCount) B on tag — too large. Shorten entries or use NTAG216.", true)
        } else if byteCount > 480 {
            return ("\(byteCount) B on tag — needs NTAG216", false)
        } else if byteCount > ntag213URIBudget {
            return ("\(byteCount) B on tag — needs NTAG215/216 (NTAG213 ~\(ntag213URIBudget) B URI)", true)
        } else {
            return ("\(byteCount) B on tag — fits NTAG213+", false)
        }
    }

    // MARK: - Wire encode / decode

    private static func encodePayload(_ chip: NFCChipProfile) -> String? {
        let compact = compactArray(from: chip)
        guard JSONSerialization.isValidJSONObject(compact),
              let jsonData = try? JSONSerialization.data(withJSONObject: compact, options: []) else {
            return nil
        }
        let payload: Data
        if let zipped = zlibCompress(jsonData), zipped.count + 1 < jsonData.count {
            var prefixed = Data([0x01])
            prefixed.append(zipped)
            payload = prefixed
        } else {
            payload = jsonData
        }
        let encoded = base64url(payload)
        guard !encoded.isEmpty, encoded.utf8.count <= maxEncodedLength else { return nil }
        return encoded
    }

    private static func decodePayload(_ encoded: String) -> NFCChipProfile? {
        guard let data = base64urlDecode(encoded), data.count <= maxEncodedLength, !data.isEmpty else {
            return nil
        }
        if let json = tryUTF8JSON(data) {
            return profile(fromJSON: json)
        }
        if data[data.startIndex] == 0x01,
           let inflated = zlibDecompress(data.dropFirst()),
           let json = tryUTF8JSON(inflated) {
            return profile(fromJSON: json)
        }
        if let inflated = zlibDecompress(data), let json = tryUTF8JSON(inflated) {
            return profile(fromJSON: json)
        }
        // Legacy named Codable JSON
        if let chip = try? JSONDecoder().decode(NFCChipProfile.self, from: data) {
            return chip
        }
        return nil
    }

    private static func compactArray(from chip: NFCChipProfile) -> [Any] {
        var row: [Any] = [
            chip.name,
            compactDob(chip.dob),
            compactBlood(chip.blood),
            chip.donor ? 1 : 0,
            chip.allergies,
            chip.meds,
            chip.conditions,
            chip.contacts.map { [$0.name, $0.rel, $0.phone] as [Any] }
        ]
        if !chip.updated.isEmpty {
            row.append(compactUpdatedString(chip.updated))
        }
        return row
    }

    private static func profile(fromJSON json: Any) -> NFCChipProfile? {
        if let arr = json as? [Any] { return profile(fromArray: arr) }
        if let obj = json as? [String: Any] { return profile(fromObject: obj) }
        return nil
    }

    private static func profile(fromArray arr: [Any]) -> NFCChipProfile {
        func str(_ i: Int) -> String {
            guard i < arr.count else { return "" }
            if let s = arr[i] as? String { return s }
            if let n = arr[i] as? NSNumber { return n.stringValue }
            return ""
        }
        func strs(_ i: Int) -> [String] {
            guard i < arr.count, let a = arr[i] as? [Any] else { return [] }
            return a.compactMap { $0 as? String }
        }
        let donor: Bool = {
            guard Idx.donor < arr.count else { return false }
            if let b = arr[Idx.donor] as? Bool { return b }
            if let n = arr[Idx.donor] as? NSNumber { return n.intValue != 0 }
            return false
        }()
        let contacts: [NFCChipContact] = {
            guard Idx.contacts < arr.count, let rows = arr[Idx.contacts] as? [Any] else { return [] }
            return rows.compactMap { row -> NFCChipContact? in
                guard let parts = row as? [Any] else { return nil }
                let name = parts.indices.contains(0) ? (parts[0] as? String ?? "") : ""
                let rel = parts.indices.contains(1) ? (parts[1] as? String ?? "") : ""
                let phone = parts.indices.contains(2) ? (parts[2] as? String ?? "") : ""
                return NFCChipContact(name: name, rel: rel, phone: phone)
            }
        }()
        return NFCChipProfile(
            name: str(Idx.name),
            dob: expandDob(str(Idx.dob)),
            blood: expandBlood(arr.indices.contains(Idx.blood) ? arr[Idx.blood] : ""),
            donor: donor,
            allergies: strs(Idx.allergies),
            meds: strs(Idx.meds),
            conditions: strs(Idx.conditions),
            contacts: contacts,
            updated: expandUpdated(str(Idx.updated))
        )
    }

    private static func profile(fromObject obj: [String: Any]) -> NFCChipProfile {
        func str(_ k: String) -> String { obj[k] as? String ?? "" }
        func strs(_ k: String) -> [String] { obj[k] as? [String] ?? [] }
        let contacts: [NFCChipContact] = {
            guard let rows = obj["contacts"] as? [[String: Any]] else { return [] }
            return rows.map {
                NFCChipContact(
                    name: $0["name"] as? String ?? "",
                    rel: $0["rel"] as? String ?? "",
                    phone: $0["phone"] as? String ?? ""
                )
            }
        }()
        let donor: Bool = {
            if let b = obj["donor"] as? Bool { return b }
            if let n = obj["donor"] as? NSNumber { return n.boolValue }
            return false
        }()
        return NFCChipProfile(
            name: str("name"),
            dob: str("dob"),
            blood: str("blood"),
            donor: donor,
            allergies: strs("allergies"),
            meds: strs("meds"),
            conditions: strs("conditions"),
            contacts: contacts,
            updated: str("updated")
        )
    }

    private static func compactBlood(_ blood: String) -> Any {
        let t = blood.trimmingCharacters(in: .whitespacesAndNewlines)
        if let i = bloodTypes.firstIndex(of: t) { return i }
        return t
    }

    private static func expandBlood(_ value: Any) -> String {
        if let i = value as? Int, bloodTypes.indices.contains(i) { return bloodTypes[i] }
        if let n = value as? NSNumber, bloodTypes.indices.contains(n.intValue) {
            return bloodTypes[n.intValue]
        }
        return value as? String ?? ""
    }

    private static func compactDob(_ dob: String) -> String {
        let digits = dob.filter(\.isNumber)
        if digits.count == 8 { return String(digits.suffix(6)) }
        if digits.count == 6 { return digits }
        return dob
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

    private static func compactUpdated(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyMMdd"
        return f.string(from: date)
    }

    private static func compactUpdatedString(_ updated: String) -> String {
        let digits = updated.filter(\.isNumber)
        if digits.count >= 8 { return String(digits.prefix(8).suffix(6)) }
        if digits.count == 6 { return digits }
        return updated
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

    private static func ndefURIBody(from fullURL: String) -> String {
        if let range = fullURL.range(of: "https://") {
            return String(fullURL[range.upperBound...])
        }
        if let range = fullURL.range(of: "http://") {
            return String(fullURL[range.upperBound...])
        }
        return fullURL
    }

    private static func tryUTF8JSON(_ data: Data) -> Any? {
        guard let first = data.first, first == UInt8(ascii: "{") || first == UInt8(ascii: "[") else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data, options: [])
    }

    /// Foundation zlib (iOS 13+) — same wrapper `DecompressionStream('deflate')` expects.
    private static func zlibCompress(_ data: Data) -> Data? {
        do {
            let out: NSData = try (data as NSData).compressed(using: .zlib)
            return out as Data
        } catch {
            return nil
        }
    }

    private static func zlibDecompress(_ data: Data) -> Data? {
        do {
            let out: NSData = try (data as NSData).decompressed(using: .zlib)
            return out as Data
        } catch {
            return nil
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

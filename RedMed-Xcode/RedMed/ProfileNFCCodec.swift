import Compression
import CryptoKit
import Foundation

/// On-chip profile after decode — must stay compatible with the hosted card page
/// (`tapper.html` `#d=` decrypt).
struct NFCChipProfile: Codable, Equatable, Sendable {
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

struct NFCChipContact: Codable, Equatable, Sendable {
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
/// embedded in `tapper.html`. This is packing/obfuscation so the fragment is not
/// casual plaintext JSON — any phone that loads tapper.html can decrypt. EMS must
/// read the band with no account; a private key would defeat the product.
///
/// Legacy still decodes:
/// - Named JSON objects
/// - Pre-AES compact arrays `[name, dob, blood, donor, allergies, meds, conditions, contacts, updated?]`
/// - Optional `0x01` zlib wrapper (and bare zlib) around those payloads
enum ProfileNFCCodec {
    private static let maxEncodedLength = 8192
    /// Version byte for legacy zlib-wrapped JSON.
    private static let zlibVersion: UInt8 = 0x01
    /// Version byte for AES-GCM sealed payloads.
    private static let aesVersion: UInt8 = 0x02
    /// Shared with `tapper.html` — derive AES-256 key via SHA-256.
    private static let keyLabel = "RedMed-NFC-AES-GCM-v1"
    private static let bloodTypes = ["O+", "O-", "A+", "A-", "B+", "B-", "AB+", "AB-"]

    /// Compact array indexes for AES / current writes (must match tapper.html).
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

    /// Pre-AES compact array: `[name, dob, blood, donor, allergies, meds, conditions, contacts, updated?]`
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

    /// Stable key — do not re-hash SHA-256 on every seal/open.
    private static let aesKey = SymmetricKey(data: Data(SHA256.hash(data: Data(keyLabel.utf8))))

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
    /// Stamps a fresh `updated` time (band write / capacity). In-app preview must use
    /// `buildPreviewURLString` so SwiftUI body re-evals do not mint a new AES ciphertext.
    /// Owner writes always use `AppConfig.medicalCardBaseURL` + `#d=` (fail closed
    /// if a caller passes a vendor / social / short-link base).
    /// `nonisolated` — NFC write packs from `Task.detached`.
    nonisolated static func buildURLString(chip: NFCChipProfile, baseURL: String = AppConfig.medicalCardBaseURL) -> String? {
        guard baseURL == AppConfig.medicalCardBaseURL else { return nil }
        var chip = chip
        chip.updated = ISO8601DateFormatter().string(from: Date())
        guard let encoded = encodePayload(chip) else { return nil }
        let urlString = baseURL + "#d=" + encoded
        guard AppConfig.OwnerBandURI.isValidWriteURL(urlString) else { return nil }
        return urlString
    }

    static func buildURLString(profile: ProfileData, baseURL: String = AppConfig.medicalCardBaseURL) -> String? {
        buildURLString(chip: chipProfile(from: profile), baseURL: baseURL)
    }

    /// Stable `#d=` for WKWebView embed — keeps `chip.updated` (or one stamp if empty)
    /// and must only be called when durable fields change, not every `body` pass.
    /// `nonisolated` — AES pack from `Task.detached` (unlock prefetch / RedMed sync).
    nonisolated static func buildPreviewURLString(chip: NFCChipProfile, baseURL: String = AppConfig.medicalCardBaseURL) -> String? {
        guard baseURL == AppConfig.medicalCardBaseURL else { return nil }
        var chip = chip
        if chip.updated.isEmpty {
            chip.updated = ISO8601DateFormatter().string(from: Date())
        }
        guard let encoded = encodePayload(chip) else { return nil }
        let urlString = baseURL + "#d=" + encoded
        guard AppConfig.OwnerBandURI.isValidWriteURL(urlString) else { return nil }
        return urlString
    }

    static func buildPreviewURLString(profile: ProfileData, baseURL: String = AppConfig.medicalCardBaseURL) -> String? {
        buildPreviewURLString(chip: chipProfile(from: profile), baseURL: baseURL)
    }

    /// Strip `#d=` from a full tapper URL (or pass through a bare fragment).
    /// `nonisolated` — NFC callbacks / `Task.detached` pack path.
    nonisolated static func extractPayload(fromURLString raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let range = trimmed.range(of: "#d=") {
            let payload = String(trimmed[range.upperBound...])
            return payload.isEmpty ? nil : payload
        }
        return trimmed
    }

    /// Owner RedMed / prefetch — stable `#d=` fragment only (no URL prefix).
    /// Lives here (not on MainActor `PasserbyHTMLCardView`) so `Task.detached` stays clean under Swift 6.
    nonisolated static func previewPayload(from chip: NFCChipProfile) -> String? {
        guard let url = buildPreviewURLString(chip: chip) else { return nil }
        return extractPayload(fromURLString: url)
    }

    /// Empty-chip AES `#d=` — app-embed first paint uses `__REDMED_PROFILE` and skips
    /// WebCrypto, so unlock must not wait on a fresh seal. Warm during shell cache fill.
    nonisolated static let placeholderPreviewPayload: String = {
        var chip = NFCChipProfile()
        chip.updated = "0"
        return previewPayload(from: chip) ?? "0"
    }()

    /// Plain object JSON for in-app `window.__REDMED_PROFILE` — skips WebCrypto decrypt.
    /// Shape matches `tapper.html` `sanitizeProfile` (name/dob/blood/lists/contacts).
    /// `nonisolated` — pairs with `previewPayload` off the main actor.
    nonisolated static func embedProfileJSON(from chip: NFCChipProfile) -> String? {
        let contacts: [[String: String]] = chip.contacts.map {
            ["name": $0.name, "rel": $0.rel, "phone": $0.phone, "detail": ""]
        }
        let obj: [String: Any] = [
            "name": chip.name,
            "dob": chip.dob,
            "blood": chip.blood,
            "donor": chip.donor,
            "updated": chip.updated,
            "allergies": chip.allergies,
            "meds": chip.meds,
            "conditions": chip.conditions,
            "contacts": contacts
        ]
        guard JSONSerialization.isValidJSONObject(obj),
              let data = try? JSONSerialization.data(withJSONObject: obj, options: []),
              let json = String(data: data, encoding: .utf8) else { return nil }
        // Safe to splice into a <script> (WKWebView loadHTMLString). Raw
        // JSONSerialization does not escape `<`, so a field containing
        // `</script>` would break out of the boot script.
        return json
            .replacingOccurrences(of: "<", with: "\\u003c")
            .replacingOccurrences(of: "\u{2028}", with: "\\u2028")
            .replacingOccurrences(of: "\u{2029}", with: "\\u2029")
    }

    static func embedProfileJSON(from profile: ProfileData) -> String? {
        embedProfileJSON(from: chipProfile(from: profile))
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
            return ("\(byteCount) bytes on tag — too large for NXP NTAG216. Shorten entries.", true)
        }
        return ("\(byteCount) bytes on tag — NXP NTAG216", false)
    }

    // MARK: - Encode / decode

    private nonisolated static func encodePayload(_ chip: NFCChipProfile) -> String? {
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
        if let chip = try? JSONDecoder().decode(NFCChipProfile.self, from: data) {
            return chip
        }
        return nil
    }

    private nonisolated static func compactArray(from chip: NFCChipProfile) -> [Any] {
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

    /// Pre-AES bands used `[name, dob, blood, donor, …]`. AES bands use
    /// `[blood, allergies, meds, emergencyPhone, …]`. Detect before mapping.
    private static func isLegacyCompactArray(_ arr: [Any]) -> Bool {
        // Current schema puts donor (0/1/bool) at index 8 when length ≥ 9.
        if arr.count >= 9, isDonorFlag(arr[8]) {
            return false
        }
        guard arr.count >= 4 else { return false }

        let donorLike = isDonorFlag(arr[3])
        let allergiesAreArray = arr.count > LegacyIdx.allergies && arr[LegacyIdx.allergies] is [Any]
        if donorLike && allergiesAreArray {
            return true
        }

        // Blood packed as Int 0…7 at index 2 (legacy compactBlood).
        if donorLike, isPackedBloodIndex(arr[LegacyIdx.blood]) {
            return true
        }

        // Name + compact/ISO dob at 0/1, donor flag at 3, ≤9 slots.
        if donorLike,
           arr[LegacyIdx.name] is String,
           looksLikeDob(arr[LegacyIdx.dob]),
           arr.count <= 9 {
            let name = arr[LegacyIdx.name] as? String ?? ""
            if !bloodTypes.contains(name) {
                return true
            }
        }
        return false
    }

    private static func isDonorFlag(_ value: Any) -> Bool {
        if value is Bool { return true }
        if let n = value as? NSNumber {
            return n.intValue == 0 || n.intValue == 1
        }
        if let s = value as? String {
            return s == "0" || s == "1"
        }
        return false
    }

    private static func isPackedBloodIndex(_ value: Any) -> Bool {
        if let n = value as? NSNumber {
            return (0...7).contains(n.intValue)
        }
        return false
    }

    private static func looksLikeDob(_ value: Any) -> Bool {
        guard let s = value as? String else {
            return value is NSNumber
        }
        let digits = s.filter(\.isNumber)
        return digits.count == 6 || digits.count == 8 || s.contains("-")
    }

    private static func profile(fromArray arr: [Any]) -> NFCChipProfile {
        if isLegacyCompactArray(arr) {
            return profile(fromLegacyArray: arr)
        }
        return profile(fromCurrentArray: arr)
    }

    private static func profile(fromCurrentArray arr: [Any]) -> NFCChipProfile {
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
            blood: expandBlood(arr.indices.contains(Idx.blood) ? arr[Idx.blood] : ""),
            donor: donorFlag(Idx.donor),
            allergies: list(Idx.allergies),
            meds: list(Idx.meds),
            conditions: list(Idx.conditions),
            contacts: contacts(Idx.contacts),
            updated: str(Idx.updated)
        )
        // Reject lone "0"/"1" so a misclassified legacy donor never becomes tel:1.
        let emergency = usableEmergencyPhone(str(Idx.emergencyPhone))
        if !emergency.isEmpty {
            if chip.contacts.isEmpty {
                chip.contacts = [NFCChipContact(name: "Emergency", rel: "", phone: emergency)]
            } else if chip.contacts[0].phone.isEmpty {
                chip.contacts[0].phone = emergency
            }
        }
        return chip
    }

    private static func profile(fromLegacyArray arr: [Any]) -> NFCChipProfile {
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
            if let s = arr[LegacyIdx.donor] as? String {
                return s == "1" || s.lowercased() == "true"
            }
            return false
        }()
        let contacts: [NFCChipContact] = {
            guard LegacyIdx.contacts < arr.count, let rows = arr[LegacyIdx.contacts] as? [Any] else {
                return []
            }
            return rows.compactMap { row -> NFCChipContact? in
                guard let parts = row as? [Any] else { return nil }
                let name = parts.indices.contains(0) ? (parts[0] as? String ?? "") : ""
                let rel = parts.indices.contains(1) ? (parts[1] as? String ?? "") : ""
                let phone = parts.indices.contains(2) ? (parts[2] as? String ?? "") : ""
                if name.isEmpty && rel.isEmpty && phone.isEmpty { return nil }
                return NFCChipContact(name: name, rel: rel, phone: phone)
            }
        }()
        return NFCChipProfile(
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
        // Need a real number, not a donor flag residue ("0"/"1").
        let numCount = digits.filter(\.isNumber).count
        return numCount >= 3 ? digits : ""
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
        guard let first = data.first, first == UInt8(ascii: "{") || first == UInt8(ascii: "[") else {
            return nil
        }
        return try? JSONSerialization.jsonObject(with: data, options: [])
    }

    /// Hard cap on inflated legacy payloads (bracelet / `#d=` JSON is tiny).
    private static let maxInflatedBytes = 64 * 1024

    /// zlib inflate into a fixed 64 KiB destination — never allocate unbounded output.
    /// Same wire wrapper `DecompressionStream('deflate')` / Foundation `.zlib` expect.
    private static func zlibDecompress(_ data: Data) -> Data? {
        guard !data.isEmpty else { return nil }
        var destination = Data(count: maxInflatedBytes)
        let decoded: Int = data.withUnsafeBytes { srcRaw in
            destination.withUnsafeMutableBytes { dstRaw in
                guard let src = srcRaw.bindMemory(to: UInt8.self).baseAddress,
                      let dst = dstRaw.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }
                return compression_decode_buffer(
                    dst,
                    maxInflatedBytes,
                    src,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard decoded > 0, decoded <= maxInflatedBytes else { return nil }
        destination.count = decoded
        return destination
    }

    private nonisolated static func base64url(_ data: Data) -> String {
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

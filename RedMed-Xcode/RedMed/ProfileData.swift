import SwiftUI
import Combine

enum AppTab {
    case redmed, emergency, aid, nfc
}

/// On-device RedMed profile. Empty on first launch; Keychain-backed when `persists` is true.
class ProfileData: ObservableObject {
    private static let keychainAccount = "medicalProfile.v1"
    private let persists: Bool

    /// >0 while `apply` / purge batch field writes — one `objectWillChange` at the end.
    private var bulkUpdateDepth = 0

    private var _name: String = ""
    private var _birthDate: String = ""
    private var _bloodType: String = ""
    private var _allergies: [String] = []
    private var _medications: [String] = []
    private var _conditions: [String] = []
    private var _contacts: [EmergencyContact] = []
    private var _braceletLinked: Bool = false
    private var _isOrganDonor: Bool = false
    private var _lastUpdated: String = ""

    var name: String {
        get { _name }
        set { setField(&_name, newValue) }
    }
    var birthDate: String {
        get { _birthDate }
        set { setField(&_birthDate, newValue) }
    }
    var bloodType: String {
        get { _bloodType }
        set { setField(&_bloodType, newValue) }
    }
    var allergies: [String] {
        get { _allergies }
        set { setField(&_allergies, newValue) }
    }
    var medications: [String] {
        get { _medications }
        set { setField(&_medications, newValue) }
    }
    var conditions: [String] {
        get { _conditions }
        set { setField(&_conditions, newValue) }
    }
    var contacts: [EmergencyContact] {
        get { _contacts }
        set { setField(&_contacts, newValue) }
    }
    var braceletLinked: Bool {
        get { _braceletLinked }
        set { setField(&_braceletLinked, newValue) }
    }
    var isOrganDonor: Bool {
        get { _isOrganDonor }
        set { setField(&_isOrganDonor, newValue) }
    }
    var lastUpdated: String {
        get { _lastUpdated }
        set { setField(&_lastUpdated, newValue) }
    }
    /// True while owner Edit holds draft PHI that may not yet be in Keychain.
    @Published var holdsEditingSession: Bool = false
    /// True while launch restore is in flight (or expected). Funnel waits on this.
    @Published var isRestoringFromKeychain: Bool = false
    /// One-shot so ContentView.task cannot Face ID twice in one process.
    private var didAttemptLaunchRestore = false
    /// Non-interactive Keychain+JSON work started during Face ID so Main can
    /// paint the YOU card on unlock instead of cream-while-restoring.
    private var launchPrefetchTask: Task<PersistedProfile?, Never>?

    private func setField<T: Equatable>(_ storage: inout T, _ newValue: T) {
        guard storage != newValue else { return }
        if bulkUpdateDepth == 0 { objectWillChange.send() }
        storage = newValue
    }

    private func withBulkUpdate(_ body: () -> Void) {
        bulkUpdateDepth += 1
        body()
        bulkUpdateDepth -= 1
        objectWillChange.send()
    }

    var hasData: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// YOU-card identity filled (Name, birth date, blood type). Lists may stay empty.
    var isEmergencyProfileConfigured: Bool {
        hasData
            && !birthDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !bloodType.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Main header "Linked bracelet" — real CoreNFC write + complete YOU card.
    /// Never from pack/simulate; hardware kill switch also forces Not linked.
    var showsBraceletAsLinked: Bool {
        AppConfig.nfcHardwareEnabled && braceletLinked && isEmergencyProfileConfigured
    }

    /// Any RedMed profile content that should require Face ID / passcode to edit.
    var hasSensitiveProfileData: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !birthDate.isEmpty
            || !bloodType.isEmpty
            || isOrganDonor
            || !allergies.isEmpty
            || !medications.isEmpty
            || !conditions.isEmpty
            || contacts.contains {
                !$0.name.isEmpty || !$0.relationship.isEmpty || !$0.phone.isEmpty
            }
    }

    init(persisting: Bool = true) {
        self.persists = persisting
        // If a blob is expected, start restoring so the empty funnel cannot flash.
        // Presence check only (exists) — no JSON decode here.
        if persisting && (Self.hasStoredProfile() || Self.prefersLockOnLaunch) {
            self.isRestoringFromKeychain = true
        }
    }

    /// Lightweight presence check — no JSON decode. True for old biometry ACL
    /// rows that cannot be read without interaction (`exists` treats
    /// errSecInteractionNotAllowed / errSecAuthFailed as present).
    static func hasStoredProfile() -> Bool {
        KeychainStore.exists(account: keychainAccount)
    }

    /// UserDefaults mirror of Keychain presence — hints that a stored ID is
    /// expected so the empty funnel stays hidden (cream) until restore finishes.
    static let storedProfileGateKey = "redmed.hasStoredProfileGate"

    static var prefersLockOnLaunch: Bool {
        UserDefaults.standard.bool(forKey: storedProfileGateKey)
    }

    static func setStoredProfileGate(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: storedProfileGateKey)
    }

    /// Detached copy for scanner / preview — mutations never touch the owner profile or Keychain.
    func snapshot() -> ProfileData {
        let copy = ProfileData(persisting: false)
        copy.name = name
        copy.birthDate = birthDate
        copy.bloodType = bloodType
        copy.allergies = allergies
        copy.medications = medications
        copy.conditions = conditions
        copy.contacts = contacts.map {
            EmergencyContact(name: $0.name, relationship: $0.relationship, phone: $0.phone)
        }
        copy.braceletLinked = braceletLinked
        copy.isOrganDonor = isOrganDonor
        copy.lastUpdated = lastUpdated
        return copy
    }

    /// Revert RAM fields from a `snapshot()` after a failed Keychain persist.
    func restore(from other: ProfileData) {
        withBulkUpdate {
            name = other.name
            birthDate = other.birthDate
            bloodType = other.bloodType
            allergies = other.allergies
            medications = other.medications
            conditions = other.conditions
            contacts = other.contacts.map {
                EmergencyContact(name: $0.name, relationship: $0.relationship, phone: $0.phone)
            }
            braceletLinked = other.braceletLinked
            isOrganDonor = other.isOrganDonor
            lastUpdated = other.lastUpdated
        }
    }

    /// - Returns: `true` when the Keychain write succeeded.
    /// Refuses to save an empty RAM profile over a stored Keychain blob
    /// (empty-funnel Save must not clobber). First-install Save of a newly
    /// filled ID is fine (no stored blob yet). Explicit erase deletes Keychain first.
    @discardableResult
    func persist() -> Bool {
        guard persists else { return false }
        if !hasSensitiveProfileData && (Self.hasStoredProfile() || Self.prefersLockOnLaunch) {
            return false
        }
        let stamp = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
        if hasSensitiveProfileData { lastUpdated = stamp }
        let blob = PersistedProfile(
            name: name,
            birthDate: birthDate,
            bloodType: bloodType,
            allergies: allergies,
            medications: medications,
            conditions: conditions,
            contacts: contacts.map {
                PersistedContact(name: $0.name, relationship: $0.relationship, phone: $0.phone)
            },
            braceletLinked: braceletLinked,
            isOrganDonor: isOrganDonor,
            lastUpdated: lastUpdated
        )
        guard let data = try? JSONEncoder().encode(blob) else { return false }
        let ok = KeychainStore.save(data, account: Self.keychainAccount)
        if ok { Self.setStoredProfileGate(true) }
        return ok
    }

    /// Wipe PHI from RAM without touching Keychain.
    func purgeFromMemory() {
        guard persists else { return }
        withBulkUpdate {
            name = ""
            birthDate = ""
            bloodType = ""
            allergies = []
            medications = []
            conditions = []
            contacts = []
            braceletLinked = false
            isOrganDonor = false
            lastUpdated = ""
        }
        holdsEditingSession = false
    }

    /// Reload owner profile from Keychain (non-interactive).
    @discardableResult
    func reloadFromKeychain() -> Bool {
        guard persists else { return false }
        return loadFromKeychain()
    }

    /// Start a non-interactive Keychain read + JSON decode while Face ID is
    /// up. Idempotent. Does not touch `@Published` fields until
    /// `restoreOnLaunch` adopts the result — no PHI flash under the cream cover.
    @MainActor
    func beginLaunchPrefetch() {
        guard persists else { return }
        guard !didAttemptLaunchRestore else { return }
        guard launchPrefetchTask == nil else { return }
        guard Self.hasStoredProfile() || Self.prefersLockOnLaunch else { return }
        let account = Self.keychainAccount
        launchPrefetchTask = Task.detached(priority: .utility) {
            Self.decodeBlob(KeychainStore.load(account: account, allowInteractive: false))
        }
    }

    /// Owner Main appear — load the Keychain blob into RAM. `allowInteractive`
    /// is true only here so an old biometryCurrentSet item can Face ID once
    /// and migrate to the unbound-when-unlocked ACL. Scanner sessions must
    /// not call this (owner Keychain).
    @MainActor
    func restoreOnLaunch() async {
        guard persists else { return }
        guard !didAttemptLaunchRestore else { return }
        didAttemptLaunchRestore = true
        isRestoringFromKeychain = true

        // Prefer the Face ID–overlap prefetch when it already finished.
        if let task = launchPrefetchTask {
            launchPrefetchTask = nil
            if let blob = await task.value {
                apply(blob)
                Self.setStoredProfileGate(true)
                isRestoringFromKeychain = false
                return
            }
            // Prefetch miss (empty / old biometry ACL) — fall through to
            // interactive migrate once.
        }

        let ok = await reloadFromKeychainAsync(allowInteractive: true)
        if ok {
            Self.setStoredProfileGate(true)
            isRestoringFromKeychain = false
            return
        }
        // Load failed. If a blob is expected, keep the gate so the funnel
        // stays hidden (cream) instead of an empty Save that could clobber.
        if Self.hasStoredProfile() || Self.prefersLockOnLaunch {
            Self.setStoredProfileGate(true)
        } else {
            Self.setStoredProfileGate(false)
        }
        isRestoringFromKeychain = false
    }

    /// Shared `PersistedProfile` → `NFCChipProfile` mapping.
    private static func chip(from blob: PersistedProfile) -> NFCChipProfile {
        NFCChipProfile(
            name: blob.name,
            dob: blob.birthDate,
            blood: blob.bloodType,
            donor: blob.isOrganDonor,
            allergies: blob.allergies,
            meds: blob.medications,
            conditions: blob.conditions,
            contacts: blob.contacts.map {
                NFCChipContact(name: $0.name, rel: $0.relationship, phone: $0.phone)
            },
            updated: blob.lastUpdated
        )
    }

    /// Off-main Keychain + JSON decode, then apply on MainActor.
    /// `allowInteractive` is for the one-time launch migrate only — not every save.
    @MainActor
    @discardableResult
    func reloadFromKeychainAsync(allowInteractive: Bool = false) async -> Bool {
        guard persists else { return false }
        let account = Self.keychainAccount
        let blob: PersistedProfile?
        if allowInteractive {
            // Interactive migrate may present Face ID — stay on main.
            let data = KeychainStore.load(account: account, allowInteractive: true)
            blob = Self.decodeBlob(data)
        } else {
            blob = await Task.detached(priority: .userInitiated) {
                Self.decodeBlob(KeychainStore.load(account: account, allowInteractive: false))
            }.value
        }
        guard let blob else { return false }
        apply(blob)
        return true
    }

    private static func decodeBlob(_ data: Data?) -> PersistedProfile? {
        guard let data,
              let decoded = try? JSONDecoder().decode(PersistedProfile.self, from: data) else {
            return nil
        }
        return decoded
    }

    /// - Returns: `true` when a profile blob was loaded from Keychain.
    @discardableResult
    private func loadFromKeychain() -> Bool {
        guard let data = KeychainStore.load(account: Self.keychainAccount),
              let blob = try? JSONDecoder().decode(PersistedProfile.self, from: data) else { return false }
        apply(blob)
        return true
    }

    private func apply(_ blob: PersistedProfile) {
        // One objectWillChange for the whole blob — unlock must not storm the tab tree.
        withBulkUpdate {
            if name != blob.name { name = blob.name }
            if birthDate != blob.birthDate { birthDate = blob.birthDate }
            if bloodType != blob.bloodType { bloodType = blob.bloodType }
            if allergies != blob.allergies { allergies = blob.allergies }
            if medications != blob.medications { medications = blob.medications }
            if conditions != blob.conditions { conditions = blob.conditions }
            let nextContacts = blob.contacts.map { $0.asEmergencyContact() }
            // Compare fields only — EmergencyContact.id is a fresh UUID each map.
            let contactsChanged = contacts.count != nextContacts.count
                || zip(contacts, nextContacts).contains {
                    $0.name != $1.name || $0.relationship != $1.relationship || $0.phone != $1.phone
                }
            if contactsChanged { contacts = nextContacts }
            if braceletLinked != blob.braceletLinked { braceletLinked = blob.braceletLinked }
            if isOrganDonor != blob.isOrganDonor { isOrganDonor = blob.isOrganDonor }
            if lastUpdated != blob.lastUpdated { lastUpdated = blob.lastUpdated }
        }
    }

    /// Band pairing flag for Main / NFC chrome.
    /// `true` only after a real CoreNFC write; cleared when RedMed is edited.
    /// Callers must not set `true` from pack/simulate paths.
    func setBraceletPaired(_ paired: Bool) {
        if paired && !AppConfig.nfcHardwareEnabled { return }
        guard braceletLinked != paired else {
            if persists { _ = persist() }
            return
        }
        braceletLinked = paired
        if persists { _ = persist() }
    }

    /// Chip holds a snapshot — any real profile edit unpairs until the band is rewritten.
    func clearBraceletPairingAfterProfileEdit() {
        guard braceletLinked else { return }
        braceletLinked = false
    }

    /// Owner Help erase — Keychain profile, vault files, RAM, pasteboard.
    /// Does not rewrite or wipe a physical band (passive NFC; no remote erase).
    /// Call only after Face ID / passcode success.
    func eraseAllLocalData() {
        guard persists else { return }
        KeychainStore.delete(account: Self.keychainAccount)
        Self.setStoredProfileGate(false)
        ConsentSettings.clearAcceptance()
        purgeFromMemory()
        VaultHistoryStore.shared.clear()
        HIPAAOfflineVault.removeAll()
        SecurePasteboard.clear()
        NotificationCenter.default.post(name: .redMedDidEraseLocalData, object: nil)
    }
}

extension Notification.Name {
    /// Posted after owner Help erase clears Keychain + vault.
    static let redMedDidEraseLocalData = Notification.Name("redMedDidEraseLocalData")
    /// Crash / SOS armed — ContentView jumps to 911 without observing CrashMotionGuard.
    static let redMedSurvivalArmed = Notification.Name("redMedSurvivalArmed")
    /// Owner RedMed embed tapped Not linked / Linked bracelet — ContentView selects NFC.
    static let redMedOpenNFCTab = Notification.Name("redMedOpenNFCTab")
    /// Preview / Scan tap card presented — PrivacySnapshotGuard must not cover it.
    static let redMedTapCardPresentationDidChange = Notification.Name("redMedTapCardPresentationDidChange")
}

struct EmergencyContact: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var relationship: String
    var phone: String

    /// Digits (and leading +) for `tel:` / `sms:` URLs.
    var dialDigits: String {
        var result = ""
        for ch in phone {
            if ch.isNumber {
                result.append(ch)
            } else if ch == "+", result.isEmpty {
                result.append(ch)
            }
        }
        return result
    }

    /// Combined subtitle for list rows (`Relationship · phone`).
    /// US numbers display as `(XXX) XXX-XXXX`; 911 stays 911. Stored `phone`
    /// digits are not rewritten here.
    var detail: String {
        get {
            let shownPhone: String = {
                guard !phone.isEmpty else { return "" }
                let parsed = CountryDialCode.parse(phone)
                if parsed.country.dialCode == "+1" {
                    return CountryDialCode.formattedNANP(digits: parsed.localNumber)
                }
                return phone
            }()
            return [relationship, shownPhone].filter { !$0.isEmpty }.joined(separator: " · ")
        }
        set {
            let parts = newValue
                .split(separator: "·", maxSplits: 1)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count > 1 {
                relationship = parts[0]
                phone = parts[1]
            } else if parts.count == 1 {
                let only = parts[0]
                let digitCount = only.filter(\.isNumber).count
                let letterCount = only.filter(\.isLetter).count
                if digitCount >= 7 && digitCount >= letterCount {
                    phone = only
                    relationship = ""
                } else {
                    relationship = only
                    phone = ""
                }
            } else {
                relationship = ""
                phone = ""
            }
        }
    }

    init(name: String, relationship: String = "", phone: String = "") {
        self.name = name
        self.relationship = relationship
        self.phone = phone
    }

    /// Legacy Keychain / NFC path: `detail` is `"Relationship · phone"`.
    init(name: String, detail: String) {
        self.name = name
        self.relationship = ""
        self.phone = ""
        self.detail = detail
    }
}

private struct PersistedProfile: Codable, Sendable {
    var name: String
    var birthDate: String
    var bloodType: String
    var allergies: [String]
    var medications: [String]
    var conditions: [String]
    var contacts: [PersistedContact]
    var braceletLinked: Bool
    var isOrganDonor: Bool
    var lastUpdated: String
}

/// Keychain contact blob. Prefers `relationship` + `phone`; still reads legacy `detail`.
private struct PersistedContact: Codable, Sendable {
    var name: String
    var relationship: String
    var phone: String
    /// Legacy combined field — written for older readers, used when loading old blobs.
    var detail: String

    init(name: String, relationship: String, phone: String) {
        self.name = name
        self.relationship = relationship
        self.phone = phone
        self.detail = [relationship, phone].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        let rel = try c.decodeIfPresent(String.self, forKey: .relationship) ?? ""
        let ph = try c.decodeIfPresent(String.self, forKey: .phone) ?? ""
        let legacy = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
        if !rel.isEmpty || !ph.isEmpty {
            relationship = rel
            phone = ph
            detail = [rel, ph].filter { !$0.isEmpty }.joined(separator: " · ")
        } else {
            let parsed = EmergencyContact(name: name, detail: legacy)
            relationship = parsed.relationship
            phone = parsed.phone
            detail = legacy
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name, forKey: .name)
        try c.encode(relationship, forKey: .relationship)
        try c.encode(phone, forKey: .phone)
        try c.encode(detail, forKey: .detail)
    }

    private enum CodingKeys: String, CodingKey {
        case name, relationship, phone, detail
    }

    func asEmergencyContact() -> EmergencyContact {
        EmergencyContact(name: name, relationship: relationship, phone: phone)
    }
}

// MARK: - First Aid Topics
struct AidTopic {
    let id: String
    let title: String
    let symptoms: [String]
    let care: [String]
}

/// Lazy bag so Aid strings are not built until Roadside Aid is opened.
enum AidTopicCatalog {
    static let topics: [String: AidTopic] = _makeTopics()

    /// Prefetch off the main thread after Aid's first paint.
    static func warmUp() {
        DispatchQueue.global(qos: .userInitiated).async {
            _ = topics
        }
    }

    private static func _makeTopics() -> [String: AidTopic] {
        [
    "car-crash": AidTopic(
        id: "car-crash", title: "Car Crash",
        symptoms: ["Impact injury — any speed", "Unresponsive or confused occupant", "Visible bleeding or deformity"],
        care: ["Call \(EmergencyNumber.current) — give exact location and number of people", "Turn on hazards. Stay at the scene", "Do NOT move them unless there is fire, rising water, or oncoming traffic", "If you must move: slide them as one unit — never twist the neck", "Control bleeding: press hard with cloth, do not lift to check", "Keep them warm and still until EMS arrives"]
    ),

    "head-pupils": AidTopic(
        id: "head-pupils", title: "Head & Pupils",
        symptoms: ["Blow to the head", "Unequal, very large ('blown'), or non-reactive pupils", "Confusion, vomiting, or worsening over minutes"],
        care: ["Call \(EmergencyNumber.current) immediately", "Shine a light — pupils should shrink equally; blown or unequal = serious", "Keep head, neck, and spine completely still — do not bend or twist", "Do NOT remove a motorcycle helmet unless the airway is blocked and you are trained", "Watch for deterioration: worsening confusion, repeated vomiting, one pupil larger", "If unconscious but breathing, recovery position only if no spinal injury suspected"]
    ),
    "spinal": AidTopic(
        id: "spinal", title: "Spinal",
        symptoms: ["Fall, crash, or diving injury", "Neck or back pain after impact", "Numbness, tingling, or can't move arms/legs"],
        care: ["Call \(EmergencyNumber.current)", "Do NOT move them — keep head and neck still", "Hold the head in the position you found it — do not bend or twist", "Move only if fire, rising water, or oncoming traffic — then slide as one unit", "Keep them warm and still until EMS arrives", "Watch breathing — be ready for CPR without turning the neck"]
    ),
    "find-bleeding": AidTopic(
        id: "find-bleeding", title: "Find Bleeding",
        symptoms: ["Trauma with clothing on — bleeding may be hidden", "Belly pain, rigidity, or bruising after impact", "Rapidly dropping consciousness"],
        care: ["Call \(EmergencyNumber.current) first", "Cut or pull clothing away — expose the entire body to find all wounds", "Press hard on every bleeding source you find", "Check the abdomen in all 4 quadrants — tell \(EmergencyNumber.current) exactly where it hurts or is hard", "Internal bleeding cannot be stopped in the field — keep them still and warm"]
    ),
    "bad-bleeding": AidTopic(
        id: "bad-bleeding", title: "Bad Bleeding",
        symptoms: ["Blood spurting in pulses (arterial)", "Soaks through cloth in under 1 minute", "Large pool of blood forming"],
        care: ["Call \(EmergencyNumber.current) — uncontrolled bleeding kills in minutes", "Press with both hands as hard as you can — your full body weight if needed", "Do NOT lift to check — it restarts clotting. Add more cloth on top", "For limbs: tourniquet 2–3 inches above wound. Note the time", "Keep pressure until EMS takes over — do not stop"]
    ),
    "belt-tourniquet": AidTopic(
        id: "belt-tourniquet", title: "Belt Tourniquet",
        symptoms: ["Severe limb bleeding that won't stop with pressure", "Amputation or near-amputation", "No commercial tourniquet available"],
        care: ["Thread belt 2–3 inches above wound — not on the joint", "Pull as tight as humanly possible and buckle or tie off", "Twist a stick through the loop and keep twisting until bleeding stops", "Secure the stick so it can't unwind", "Write the time on skin near the tourniquet", "Do NOT remove it — only EMS does that"]
    ),
    "gunshot-stab": AidTopic(
        id: "gunshot-stab", title: "Gunshot / Stab",
        symptoms: ["Penetrating wound to chest, abdomen, neck, or limb", "Sucking chest wound (air noise)", "Rapidly worsening shock"],
        care: ["Call \(EmergencyNumber.current) first — scene must be safe before you approach", "Chest wound: seal it on 3 sides with plastic or foil to stop air entry", "Abdomen: do NOT push organs back in. Cover with clean wet cloth", "Limb: pack wound tightly with cloth, apply direct pressure or tourniquet", "Keep victim still and warm. Note time of injury", "Stay on the line with \(EmergencyNumber.current) — follow their guidance"]
    ),
    "cpr": AidTopic(
        id: "cpr", title: "CPR",
        symptoms: ["Unresponsive — no reaction to shouting or shoulder tap", "No normal breathing (gasping is not breathing)", "No pulse found at neck or wrist"],
        care: ["Call \(EmergencyNumber.current) immediately — or have someone else call while you start", "Place heel of hand center of chest, other hand on top", "Push hard and fast: 2 inches deep, 100–120 per minute", "Allow full chest recoil between compressions — don't lean", "If trained: give 2 rescue breaths every 30 compressions", "Use AED as soon as available — turn on and follow voice prompts", "Keep going until EMS arrives or person starts breathing normally"]
    ),
    "choking": AidTopic(
        id: "choking", title: "Choking",
        symptoms: ["Cannot speak, cry, or make a strong cough", "Hands at throat (universal choking sign)", "Face turning red then blue"],
        care: ["Ask 'Are you choking?' — if they can cough, encourage coughing", "If they cannot cough or speak: stand behind them, lean them forward", "Give 5 firm back blows between shoulder blades with heel of hand", "If no result: 5 abdominal thrusts (Heimlich) — fist above navel, pull sharply inward and upward", "Alternate back blows and abdominal thrusts until object clears or they lose consciousness", "If unconscious: lower to ground, call \(EmergencyNumber.current), begin CPR"]
    ),
    "shock": AidTopic(
        id: "shock", title: "Shock",
        symptoms: ["Pale, cold, clammy skin", "Rapid weak pulse", "Confusion, anxiety, or loss of consciousness"],
        care: ["Call \(EmergencyNumber.current) immediately", "Lay them flat — do NOT let them sit up or walk", "Elevate legs 12 inches unless head, neck, or spine injury is suspected", "Keep them warm — cover with a blanket or jacket", "Do NOT give food, water, or medication", "Loosen tight clothing at neck and chest", "Stay with them and monitor breathing until EMS arrives"]
    ),
    "cold-hypothermia": AidTopic(
        id: "cold-hypothermia", title: "Cold (Hypothermia)",
        symptoms: ["Shivering, confusion, slurred speech", "Skin feels very cold and may look blue or pale", "Stumbling, loss of coordination"],
        care: ["Call \(EmergencyNumber.current) for severe cases", "Move them to a warm, sheltered location", "Remove wet clothing gently — cut if needed", "Warm the core first: chest, neck, armpits, groin — not the limbs", "Use blankets, body heat, or warm (not hot) packs wrapped in cloth", "Do NOT rub or massage limbs — it can cause cardiac arrest", "Give warm drinks only if fully conscious and able to swallow"]
    ),
    "heat-stroke": AidTopic(
        id: "heat-stroke", title: "Heat Exhaustion & Stroke",
        symptoms: ["Heavy sweating, weakness, cold/pale/clammy skin (exhaustion)", "Hot, red, dry or damp skin, rapid pulse, confusion (stroke)", "Nausea, fainting, body temp above 103°F"],
        care: ["Heat stroke: call \(EmergencyNumber.current) immediately — it is life-threatening", "Move to cool or shaded area", "Cool rapidly: remove extra clothing, apply ice packs to neck/armpits/groin", "If conscious: sip cool water slowly", "Do NOT give fluids to an unconscious person", "Fan them while applying cool water to skin", "Lay them down and elevate legs if no spinal injury"]
    ),
    "burn-care": AidTopic(
        id: "burn-care", title: "Burn Care",
        symptoms: ["Redness and pain (1st degree)", "Blistering with intense pain (2nd degree)", "White, leathery, or charred skin with little pain (3rd degree — nerve damage)"],
        care: ["Call \(EmergencyNumber.current) for burns larger than the palm, on the face, hands, feet, or genitals, or any 3rd-degree burn", "Cool the burn under cool running water for 10–20 minutes — never use ice", "Remove rings, watches, and tight clothing near the burn before swelling starts", "Cover loosely with a clean, non-stick dressing or cloth", "Do NOT pop blisters or apply butter, oil, or ointment", "Watch for shock: pale, cold, rapid breathing"]
    ),
    "electrical-chemical-burns": AidTopic(
        id: "electrical-chemical-burns", title: "Electrical & Chemical Burns",
        symptoms: ["Visible entry and exit wound (electrical) — damage often worse than it looks", "Chemical contact with skin, eyes, or clothing", "Irregular heartbeat, confusion, or muscle pain after shock"],
        care: ["Do NOT touch them until you're sure the power source is off", "Call \(EmergencyNumber.current) — electrical burns cause internal damage far beyond the skin", "For chemicals: brush off dry powder first, then flush skin with running water for 20 minutes", "Remove any clothing or jewelry contaminated with the chemical", "Be ready for CPR — electrical shock can stop the heart", "Cover the burn loosely once flushed or the power is confirmed off"]
    ),
    "seizure": AidTopic(
        id: "seizure", title: "Seizure",
        symptoms: ["Sudden collapse or falling", "Jerking or stiffening of body, limbs, or face", "Loss of awareness, staring, or confusion before or after"],
        care: ["Call \(EmergencyNumber.current) if: first seizure, lasts more than 5 minutes, no recovery, injury, or in water", "Time the seizure from the start", "Clear the area — move objects that could cause injury", "Do NOT restrain them — guide gently away from danger", "Do NOT put anything in their mouth", "Cushion the head with something soft", "After it stops: roll them on their side (recovery position) to protect the airway", "Stay calm and reassure them — confusion after a seizure is normal"]
    ),
    "trauma-hospitals": AidTopic(
        id: "trauma-hospitals", title: "Find Nearby Hospitals",
        symptoms: ["Major trauma: crash, gunshot/stab, severe bleeding, head injury", "Patient unstable or deteriorating", "Need the closest ER / hospital POI on the map"],
        care: ["Call \(EmergencyNumber.current) — dispatch will route to the right facility automatically", "Do NOT self-transport a major trauma patient if EMS is available — ambulances can stabilize en route", "If you must drive: tell the ER ahead by phone so the trauma team is ready", "Note time of injury and mechanism (e.g. speed, fall height, weapon) to report on arrival"]
    ),
        ]
    }
}

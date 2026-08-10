import SwiftUI
import Combine

enum AppTab {
    case myid, emergency, aid, nfc
}

class ProfileData: ObservableObject {
    @Published var name: String
    @Published var birthDate: String
    @Published var bloodType: String
    @Published var allergies: [String]
    @Published var medications: [String]
    @Published var conditions: [String]
    @Published var contacts: [EmergencyContact]
    @Published var isOrganDonor: Bool
    @Published var lastUpdated: String
    /// True after a successful NFC write to a blank bracelet.
    @Published var braceletLinked: Bool
    /// Set after Save so NFC tab can auto-start a write session.
    @Published var pendingBraceletWrite: Bool = false

    var hasData: Bool { !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private static let storageKey = "redmed.profile.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let stored = try? JSONDecoder().decode(StoredProfile.self, from: data) {
            name = stored.name
            birthDate = stored.birthDate
            bloodType = stored.bloodType
            allergies = stored.allergies
            medications = stored.medications
            conditions = stored.conditions
            contacts = stored.contacts.map { EmergencyContact(name: $0.name, detail: $0.detail) }
            isOrganDonor = stored.isOrganDonor
            lastUpdated = stored.lastUpdated
            braceletLinked = stored.braceletLinked
        } else {
            // Empty first launch — user enters real My ID, then pairs a blank tag.
            name = ""
            birthDate = ""
            bloodType = ""
            allergies = []
            medications = []
            conditions = []
            contacts = []
            isOrganDonor = false
            lastUpdated = ""
            braceletLinked = false
        }
    }

    func touchUpdated() {
        lastUpdated = Self.todayString()
    }

    func persist() {
        let stored = StoredProfile(
            name: name,
            birthDate: birthDate,
            bloodType: bloodType,
            allergies: allergies,
            medications: medications,
            conditions: conditions,
            contacts: contacts.map { StoredContact(name: $0.name, detail: $0.detail) },
            isOrganDonor: isOrganDonor,
            lastUpdated: lastUpdated,
            braceletLinked: braceletLinked
        )
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func requestBraceletWrite() {
        pendingBraceletWrite = true
    }

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: Date())
    }

    private struct StoredProfile: Codable {
        var name: String
        var birthDate: String
        var bloodType: String
        var allergies: [String]
        var medications: [String]
        var conditions: [String]
        var contacts: [StoredContact]
        var isOrganDonor: Bool
        var lastUpdated: String
        var braceletLinked: Bool
    }

    private struct StoredContact: Codable {
        var name: String
        var detail: String
    }
}

struct EmergencyContact: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var detail: String
}

// MARK: - First Aid Topics
struct AidTopic {
    let id: String
    let title: String
    let symptoms: [String]
    let care: [String]
}

/// Compact roadside topics also mirrored on the static public card page.
let roadsideAidTopics: [AidTopic] = [
    AidTopic(
        id: "bad-bleeding", title: "Severe Bleeding",
        symptoms: ["Blood spurting or soaking cloth in under a minute", "Large pool of blood forming"],
        care: ["Call 911", "Press hard with both hands — full body weight if needed", "Do NOT lift to check — add more cloth on top", "Limb: tourniquet 2–3 inches above wound, note the time", "Keep pressure until EMS takes over"]
    ),
    AidTopic(
        id: "cpr", title: "CPR",
        symptoms: ["Unresponsive", "No normal breathing", "No pulse"],
        care: ["Call 911", "Heel of hand center of chest, other hand on top", "Push hard and fast: 2 inches, 100–120/min", "Allow full chest recoil", "Use AED as soon as available", "Continue until EMS arrives"]
    ),
    AidTopic(
        id: "choking", title: "Choking",
        symptoms: ["Cannot speak, cry, or cough forcefully", "Clutching throat"],
        care: ["If they can cough hard, let them", "5 firm back blows between shoulder blades", "5 abdominal thrusts (Heimlich)", "Alternate until object is out or they go unconscious", "If unconscious: start CPR"]
    ),
    AidTopic(
        id: "shock", title: "Shock",
        symptoms: ["Pale, cold, clammy skin", "Rapid weak pulse", "Confusion or extreme fatigue"],
        care: ["Call 911", "Lay flat; elevate legs 12 inches if no spinal/leg injury", "Control visible bleeding", "Keep warm", "Do NOT give food or water", "Do NOT let them walk"]
    ),
    AidTopic(
        id: "car-crash", title: "Car Crash",
        symptoms: ["Impact injury", "Unresponsive or confused occupant", "Visible bleeding or deformity"],
        care: ["Call 911 — give exact location and number of people", "Hazards on. Stay at the scene", "Do NOT move them unless fire, water, or traffic", "If you must move: slide as one unit — never twist the neck", "Control bleeding: press hard with cloth", "Keep warm and still until EMS"]
    ),
]

let aidTopics: [String: AidTopic] = [
    "car-crash": AidTopic(
        id: "car-crash", title: "Car Crash",
        symptoms: ["Impact injury — any speed", "Unresponsive or confused occupant", "Visible bleeding or deformity"],
        care: ["Call 911 — give exact location and number of people", "Turn on hazards. Stay at the scene", "Do NOT move them unless there is fire, rising water, or oncoming traffic", "If you must move: slide them as one unit — never twist the neck", "Control bleeding: press hard with cloth, do not lift to check", "Keep them warm and still until EMS arrives"]
    ),
    "head-pupils": AidTopic(
        id: "head-pupils", title: "Head & Pupils",
        symptoms: ["Blow to the head", "Unequal, very large ('blown'), or non-reactive pupils", "Confusion, vomiting, or worsening over minutes"],
        care: ["Call 911 immediately", "Shine a light — pupils should shrink equally; blown or unequal = serious", "Keep head, neck, and spine completely still — do not bend or twist", "Do NOT remove a motorcycle helmet unless the airway is blocked and you are trained", "Watch for deterioration: worsening confusion, repeated vomiting, one pupil larger", "If unconscious but breathing, recovery position only if no spinal injury suspected"]
    ),
    "find-bleeding": AidTopic(
        id: "find-bleeding", title: "Find Bleeding",
        symptoms: ["Trauma with clothing on — bleeding may be hidden", "Belly pain, rigidity, or bruising after impact", "Rapidly dropping consciousness"],
        care: ["Call 911 first", "Cut or pull clothing away — expose the entire body to find all wounds", "Press hard on every bleeding source you find", "Check the abdomen in all 4 quadrants — tell 911 exactly where it hurts or is hard", "Internal bleeding cannot be stopped in the field — keep them still and warm"]
    ),
    "bad-bleeding": AidTopic(
        id: "bad-bleeding", title: "Bad Bleeding",
        symptoms: ["Blood spurting in pulses (arterial)", "Soaks through cloth in under 1 minute", "Large pool of blood forming"],
        care: ["Call 911 — uncontrolled bleeding kills in minutes", "Press with both hands as hard as you can — your full body weight if needed", "Do NOT lift to check — it restarts clotting. Add more cloth on top", "For limbs: tourniquet 2–3 inches above wound. Note the time", "Keep pressure until EMS takes over — do not stop"]
    ),
    "belt-tourniquet": AidTopic(
        id: "belt-tourniquet", title: "Belt Tourniquet",
        symptoms: ["Severe limb bleeding that won't stop with pressure", "Amputation or near-amputation", "No commercial tourniquet available"],
        care: ["Thread belt 2–3 inches above wound — not on the joint", "Pull as tight as humanly possible and buckle or tie off", "Twist a stick through the loop and keep twisting until bleeding stops", "Secure the stick so it can't unwind", "Write the time on skin near the tourniquet", "Do NOT remove it — only EMS does that"]
    ),
    "gunshot-stab": AidTopic(
        id: "gunshot-stab", title: "Gunshot / Stab",
        symptoms: ["Penetrating wound to chest, abdomen, neck, or limb", "Sucking chest wound (air noise)", "Rapidly worsening shock"],
        care: ["Call 911 first — scene must be safe before you approach", "Chest wound: seal it on 3 sides with plastic or foil to stop air entry", "Abdomen: do NOT push organs back in. Cover with clean wet cloth", "Limb: pack wound tightly with cloth, apply direct pressure or tourniquet", "Keep victim still and warm. Note time of injury", "Stay on the line with 911 — follow their guidance"]
    ),
    "cpr": AidTopic(
        id: "cpr", title: "CPR",
        symptoms: ["Unresponsive — no reaction to shouting or shoulder tap", "No normal breathing (gasping is not breathing)", "No pulse found at neck or wrist"],
        care: ["Call 911 immediately — or have someone else call while you start", "Place heel of hand center of chest, other hand on top", "Push hard and fast: 2 inches deep, 100–120 per minute", "Allow full chest recoil between compressions — don't lean", "If trained: give 2 rescue breaths every 30 compressions", "Use AED as soon as available — turn on and follow voice prompts", "Keep going until EMS arrives or person starts breathing normally"]
    ),
    "choking": AidTopic(
        id: "choking", title: "Choking",
        symptoms: ["Cannot speak, cry, or cough forcefully", "High-pitched noise or no sound when breathing", "Clutching throat — universal choking sign"],
        care: ["Ask 'Are you choking?' — if they can cough hard, let them", "If they cannot: stand behind them, lean them forward", "5 firm back blows between shoulder blades with heel of hand", "5 abdominal thrusts (Heimlich): fist above navel, sharp inward-and-upward thrust", "Alternate 5 back blows + 5 thrusts until object is expelled or they go unconscious", "If they become unconscious: lower them to the floor and start CPR — each time you open the airway, look for the object before giving breaths"]
    ),
    "shock": AidTopic(
        id: "shock", title: "Shock",
        symptoms: ["Pale, cold, clammy skin", "Rapid weak pulse; rapid shallow breathing", "Confusion, anxiety, or sudden extreme fatigue"],
        care: ["Call 911 — shock is life-threatening", "Lay them flat on their back; elevate legs 12 inches if no spinal or leg injury", "Control any visible bleeding immediately", "Keep them warm — cover with a blanket or clothing", "Do NOT give food or water — aspiration risk", "Do NOT let them walk or sit up", "Talk to them calmly; keep monitoring breathing until EMS arrives"]
    ),
    "cold-hypothermia": AidTopic(
        id: "cold-hypothermia", title: "Cold (Hypothermia)",
        symptoms: ["Shivering, confusion, slurred speech", "Skin feels very cold and may look blue or pale", "Stumbling, loss of coordination"],
        care: ["Call 911 for severe cases", "Move them to a warm, sheltered location", "Remove wet clothing gently — cut if needed", "Warm the core first: chest, neck, armpits, groin — not the limbs", "Use blankets, body heat, or warm (not hot) packs wrapped in cloth", "Do NOT rub or massage limbs — it can cause cardiac arrest", "Give warm drinks only if fully conscious and able to swallow"]
    ),
    "heat-stroke": AidTopic(
        id: "heat-stroke", title: "Heat Stroke",
        symptoms: ["Hot skin — may be dry or sweaty", "Confusion, slurred speech, seizure, or unresponsiveness", "Core temperature above 104°F (40°C)"],
        care: ["Call 911 — heat stroke kills; cooling is the emergency treatment", "Move immediately into shade or air conditioning", "Remove excess clothing to expose as much skin as possible", "Cool NOW by any means: ice bath (most effective), cold wet cloths on neck/armpits/groin, fan with misting", "Do NOT give fluids if confused or unresponsive — aspiration risk", "If fully conscious and able to swallow: cold water only — no aspirin or acetaminophen"]
    ),
    "seizure": AidTopic(
        id: "seizure", title: "Seizure",
        symptoms: ["Sudden collapse or falling", "Jerking or stiffening of body, limbs, or face", "Loss of awareness, staring, or confusion before or after"],
        care: ["Call 911 if: first seizure, lasts more than 5 minutes, no recovery, injury, or in water", "Time the seizure from the start", "Clear the area — move objects that could cause injury", "Do NOT restrain them — guide gently away from danger", "Do NOT put anything in their mouth", "Cushion the head with something soft", "After it stops: roll them on their side (recovery position) to protect the airway", "Stay calm and reassure them — confusion after a seizure is normal"]
    ),
    "burns": AidTopic(
        id: "burns", title: "Burn Care",
        symptoms: ["Redness and pain (1st degree)", "Blistering with intense pain (2nd degree)", "White, leathery, or charred skin with little pain (3rd degree — nerve damage)"],
        care: ["Call 911 for burns larger than the palm, on the face, hands, feet, or genitals, or any 3rd-degree burn", "Cool the burn under cool running water for 10–20 minutes — never use ice", "Remove rings, watches, and tight clothing near the burn before swelling starts", "Cover loosely with a clean, non-stick dressing or cloth", "Do NOT pop blisters or apply butter, oil, or ointment", "Watch for shock: pale, cold, rapid breathing"]
    ),
    "electrical-chemical-burns": AidTopic(
        id: "electrical-chemical-burns", title: "Electrical & Chemical Burns",
        symptoms: ["Visible entry and exit wound (electrical) — damage often worse than it looks", "Chemical contact with skin, eyes, or clothing", "Irregular heartbeat, confusion, or muscle pain after shock"],
        care: ["Do NOT touch them until you're sure the power source is off", "Call 911 — electrical burns cause internal damage far beyond the skin", "For chemicals: brush off dry powder first, then flush skin with running water for 20 minutes", "Remove any clothing or jewelry contaminated with the chemical", "Be ready for CPR — electrical shock can stop the heart", "Cover the burn loosely once flushed or the power is confirmed off"]
    ),
    "trauma-hospitals": AidTopic(
        id: "trauma-hospitals", title: "Find Trauma Center",
        symptoms: ["Major trauma: crash, gunshot/stab, severe bleeding, head injury", "Patient unstable or deteriorating", "Unsure whether the nearest ER can handle it"],
        care: ["Call 911 — dispatch will route to the right trauma level automatically", "Do NOT self-transport a major trauma patient if EMS is available — ambulances can stabilize en route", "Level I centers offer the highest capability for the most severe trauma; Level II/III are also fully equipped for most emergencies", "If you must drive: tell the ER ahead by phone so the trauma team is ready", "Note time of injury and mechanism (e.g. speed, fall height, weapon) to report on arrival"]
    ),
]

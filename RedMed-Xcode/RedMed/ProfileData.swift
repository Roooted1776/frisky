import SwiftUI
import Combine

enum AppTab {
    case myid, emergency, aid, nfc
}

class ProfileData: ObservableObject {
    @Published var name: String = "Alex Rivera"
    @Published var birthDate: String = "March 14, 1994"
    @Published var bloodType: String = "O+"
    @Published var allergies: [String] = ["Penicillin", "Peanuts"]
    @Published var medications: [String] = ["Lisinopril 10mg — daily", "Albuterol inhaler — as needed"]
    @Published var conditions: [String] = ["Type 1 Diabetes", "Asthma"]
    @Published var contacts: [EmergencyContact] = [
        EmergencyContact(name: "Jamie Rivera", detail: "Spouse · (555) 201-4488"),
        EmergencyContact(name: "Dr. Sarah Chen", detail: "Primary Care · (555) 340-9921")
    ]

    var hasData: Bool { !name.isEmpty }

    /// Any medical profile content that should require Face ID / passcode to edit.
    var hasSensitiveProfileData: Bool {
        !name.isEmpty
            || !birthDate.isEmpty
            || !bloodType.isEmpty
            || !allergies.isEmpty
            || !medications.isEmpty
            || !conditions.isEmpty
            || contacts.contains { !$0.name.isEmpty || !$0.detail.isEmpty }
    }

    /// Whether an NFC band has been written/paired (Main header status).
    @Published var braceletLinked: Bool = false
    @Published var isOrganDonor: Bool = true
    @Published var lastUpdated: String = "Jul 28, 2026"
}

struct EmergencyContact: Identifiable {
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

let aidTopics: [String: AidTopic] = AidTopicCatalog.topics

/// Lazy bag so Aid strings are not built until Roadside Aid is opened.
enum AidTopicCatalog {
    static let topics: [String: AidTopic] = _makeTopics()

    private static func _makeTopics() -> [String: AidTopic] {
        [
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
        symptoms: ["Cannot speak, cry, or make a strong cough", "Hands at throat (universal choking sign)", "Face turning red then blue"],
        care: ["Ask 'Are you choking?' — if they can cough, encourage coughing", "If they cannot cough or speak: stand behind them, lean them forward", "Give 5 firm back blows between shoulder blades with heel of hand", "If no result: 5 abdominal thrusts (Heimlich) — fist above navel, pull sharply inward and upward", "Alternate back blows and abdominal thrusts until object clears or they lose consciousness", "If unconscious: lower to ground, call 911, begin CPR"]
    ),
    "shock": AidTopic(
        id: "shock", title: "Shock",
        symptoms: ["Pale, cold, clammy skin", "Rapid weak pulse", "Confusion, anxiety, or loss of consciousness"],
        care: ["Call 911 immediately", "Lay them flat — do NOT let them sit up or walk", "Elevate legs 12 inches unless head, neck, or spine injury is suspected", "Keep them warm — cover with a blanket or jacket", "Do NOT give food, water, or medication", "Loosen tight clothing at neck and chest", "Stay with them and monitor breathing until EMS arrives"]
    ),
    "cold-hypothermia": AidTopic(
        id: "cold-hypothermia", title: "Cold (Hypothermia)",
        symptoms: ["Shivering, confusion, slurred speech", "Skin feels very cold and may look blue or pale", "Stumbling, loss of coordination"],
        care: ["Call 911 for severe cases", "Move them to a warm, sheltered location", "Remove wet clothing gently — cut if needed", "Warm the core first: chest, neck, armpits, groin — not the limbs", "Use blankets, body heat, or warm (not hot) packs wrapped in cloth", "Do NOT rub or massage limbs — it can cause cardiac arrest", "Give warm drinks only if fully conscious and able to swallow"]
    ),
    "heat-stroke": AidTopic(
        id: "heat-stroke", title: "Heat Exhaustion & Stroke",
        symptoms: ["Heavy sweating, weakness, cold/pale/clammy skin (exhaustion)", "Hot, red, dry or damp skin, rapid pulse, confusion (stroke)", "Nausea, fainting, body temp above 103°F"],
        care: ["Heat stroke: call 911 immediately — it is life-threatening", "Move to cool or shaded area", "Cool rapidly: remove extra clothing, apply ice packs to neck/armpits/groin", "If conscious: sip cool water slowly", "Do NOT give fluids to an unconscious person", "Fan them while applying cool water to skin", "Lay them down and elevate legs if no spinal injury"]
    ),
    "seizure": AidTopic(
        id: "seizure", title: "Seizure",
        symptoms: ["Sudden collapse or falling", "Jerking or stiffening of body, limbs, or face", "Loss of awareness, staring, or confusion before or after"],
        care: ["Call 911 if: first seizure, lasts more than 5 minutes, no recovery, injury, or in water", "Time the seizure from the start", "Clear the area — move objects that could cause injury", "Do NOT restrain them — guide gently away from danger", "Do NOT put anything in their mouth", "Cushion the head with something soft", "After it stops: roll them on their side (recovery position) to protect the airway", "Stay calm and reassure them — confusion after a seizure is normal"]
    ),
    "trauma-hospitals": AidTopic(
        id: "trauma-hospitals", title: "Find Trauma Center",
        symptoms: ["Major trauma: crash, gunshot/stab, severe bleeding, head injury", "Patient unstable or deteriorating", "Unsure whether the nearest ER can handle it"],
        care: ["Call 911 — dispatch will route to the right trauma level automatically", "Do NOT self-transport a major trauma patient if EMS is available — ambulances can stabilize en route", "Level I centers offer the highest capability for the most severe trauma; Level II/III are also fully equipped for most emergencies", "If you must drive: tell the ER ahead by phone so the trauma team is ready", "Note time of injury and mechanism (e.g. speed, fall height, weapon) to report on arrival"]
    ),
        ]
    }
}

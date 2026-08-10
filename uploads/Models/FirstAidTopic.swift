import Foundation

struct FirstAidTopic: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let icon: String
    let symptoms: [String]
    let temporaryCare: [String]
}

/// Roadside help until EMS arrives.
enum FirstAidLibrary {
    static let topics: [FirstAidTopic] = [
        FirstAidTopic(
            title: "Car Crash",
            icon: "car.fill",
            symptoms: ["Injury after a crash", "Not moving or confused", "Bleeding"],
            temporaryCare: [
                "Call 911 — give location",
                "Hazards on. Don't move them unless fire or traffic",
                "If you must move them: keep head and spine still — slide or roll as one unit; don't twist the neck",
                "Press hard on bleeding. Keep head still"
            ]
        ),
        FirstAidTopic(
            title: "Head & Pupils",
            icon: "eye.fill",
            symptoms: [
                "Hit to the head",
                "Pupils unequal, blown, or not reactive",
                "Confused, vomiting, or getting worse"
            ],
            temporaryCare: [
                "Call 911",
                "Check pupils — size, equal, reactive to light?",
                "Keep head, neck, and spine still — don't twist or bend",
                "If moved, keep head and spine aligned; move the body as one unit",
                "Do NOT remove a motorcycle helmet unless trained and airway is blocked",
                "Watch for brain-bleed signs: worsening confusion, vomiting, unequal pupils"
            ]
        ),
        FirstAidTopic(
            title: "Find Bleeding",
            icon: "scissors",
            symptoms: [
                "Crash or trauma — bleeding may be hidden under clothes",
                "Belly pain or swelling after impact"
            ],
            temporaryCare: [
                "Call 911",
                "Cut clothing off to expose and find all bleeding — don't pull stuck fabric out of a wound",
                "Press hard on each bleeding source",
                "Check the belly in 4 quadrants (tell 911 where it hurts or bleeds): upper-right, upper-left, lower-right, lower-left"
            ]
        ),
        FirstAidTopic(
            title: "Bad Bleeding",
            icon: "bandage.fill",
            symptoms: ["Heavy or spurting blood", "Soaks through cloth"],
            temporaryCare: [
                "Call 911",
                "Press hard — don't lift to check",
                "Soaks through? Add more cloth on top"
            ]
        ),
        FirstAidTopic(
            title: "Belt Tourniquet",
            icon: "link",
            symptoms: [
                "Life-threatening limb bleeding that won't stop with direct pressure",
                "Arm or leg only — not neck, chest, or abdomen"
            ],
            temporaryCare: [
                "Call 911 first",
                "Only for arms/legs — never neck, chest, or abdomen",
                "Keep pressure on the wound until the belt is on",
                "Place belt 2–3 inches above the wound (not on a joint)",
                "Tighten until bleeding stops completely — it will hurt; that's expected",
                "Note the time applied — do not loosen until help arrives",
                "If belt alone won't tighten enough, use a stick/tool as a windlass through the buckle/loop and twist",
                "Last resort when direct pressure fails on a limb",
                "Improvised belts are less reliable than real tourniquets but better than uncontrolled bleeding"
            ]
        ),
        FirstAidTopic(
            title: "Gunshot / Stab",
            icon: "cross.circle.fill",
            symptoms: ["Any gunshot or stab wound"],
            temporaryCare: [
                "Call 911 now",
                "Press hard on the wound",
                "Limb won't stop? Tie above it — note time"
            ]
        ),
        FirstAidTopic(
            title: "CPR",
            icon: "heart.fill",
            symptoms: ["Not responding", "Not breathing or only gasping"],
            temporaryCare: [
                "Call 911",
                "Push hard & fast on chest center",
                "Don't stop until help arrives"
            ]
        ),
        FirstAidTopic(
            title: "Choking",
            icon: "lungs.fill",
            symptoms: ["Can't cough, speak, or breathe", "Turning blue"],
            temporaryCare: [
                "Coughing? Let them cough",
                "Can't breathe? Thrusts in and up",
                "Passes out? Call 911, start CPR"
            ]
        ),
        FirstAidTopic(
            title: "Shock",
            icon: "waveform.path",
            symptoms: ["Pale, cold, clammy", "Weak or confused after injury"],
            temporaryCare: [
                "Call 911",
                "Lay flat; raise legs only if no neck or back injury",
                "If moved, keep head and spine still when possible",
                "Keep warm — no food or water"
            ]
        ),
        FirstAidTopic(
            title: "Cold (Hypothermia)",
            icon: "snowflake",
            symptoms: [
                "Shivering — then shivering stops (worse sign)",
                "Confused, slurred speech, clumsy, very sleepy",
                "Cold skin; pale or bluish lips or fingers",
                "After a crash: wet clothes, wind, night air, stuck outside"
            ],
            temporaryCare: [
                "Call 911 if confused, not shivering anymore, or getting worse",
                "Move to shelter — car, out of wind and rain",
                "Remove wet clothes; dry them and layer coats, blankets, floor mats",
                "Insulate from cold ground — cardboard, seat cushion under them",
                "Keep warm — share body heat in a dry blanket burrito; don't rub skin",
                "Warm drinks only if fully awake and can swallow normally",
                "Don't use hot water or direct heat on skin — warm slowly"
            ]
        ),
        FirstAidTopic(
            title: "Heat (Exhaustion & Stroke)",
            icon: "sun.max.fill",
            symptoms: [
                "Hot day + weak, headache, nausea, muscle cramps",
                "Heavy sweat, then cool clammy skin (heat exhaustion)",
                "Heat stroke: hot dry skin, confusion, not sweating, passing out"
            ],
            temporaryCare: [
                "Call 911 if confused, vomiting, or hot dry skin in the heat",
                "Move to shade or AC; loosen or remove extra layers",
                "Cool fast — wet cloths on neck, armpits, groin; fan air over skin",
                "Small sips of water if fully awake — not if confused or vomiting",
                "Ice packs in a cloth on neck and armpits if you have them",
                "Stay with them until help arrives"
            ]
        )
    ]
}

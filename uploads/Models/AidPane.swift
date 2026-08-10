import SwiftUI

struct AidPane: Identifiable, Hashable {
    let id: String
    let title: String
    let blurb: String
    let icon: String
    let critical: Bool
    let topics: [FirstAidTopic]
}

enum AidPaneLibrary {
    static let panes: [AidPane] = [
        AidPane(
            id: "crash",
            title: "Crash & Head",
            blurb: "Impact · neck · pupils",
            icon: "car.fill",
            critical: false,
            topics: FirstAidLibrary.topics.filter { ["Car Crash", "Head & Pupils"].contains($0.title) }
        ),
        AidPane(
            id: "bleed",
            title: "Bleeding",
            blurb: "Pressure · tourniquet · wounds",
            icon: "drop.fill",
            critical: true,
            topics: FirstAidLibrary.topics.filter {
                ["Find Bleeding", "Bad Bleeding", "Belt Tourniquet", "Gunshot / Stab"].contains($0.title)
            }
        ),
        AidPane(
            id: "breath",
            title: "Heart & Airway",
            blurb: "CPR · choking",
            icon: "heart.fill",
            critical: true,
            topics: FirstAidLibrary.topics.filter { ["CPR", "Choking"].contains($0.title) }
        ),
        AidPane(
            id: "shock",
            title: "Shock",
            blurb: "Pale · cold · clammy",
            icon: "bolt.fill",
            critical: false,
            topics: FirstAidLibrary.topics.filter { $0.title == "Shock" }
        ),
        AidPane(
            id: "temp",
            title: "Cold & Heat",
            blurb: "Notice · warm · cool down",
            icon: "thermometer.medium",
            critical: false,
            topics: FirstAidLibrary.topics.filter {
                ["Cold (Hypothermia)", "Heat (Exhaustion & Stroke)"].contains($0.title)
            }
        )
    ]
}

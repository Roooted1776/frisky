import SwiftUI

struct AidPane: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let subtitle: String
    let iconFilled: Bool
    let topics: [(label: String, key: String)]
}

let aidPanes: [AidPane] = [
    AidPane(id: "crash", emoji: "🚗", title: "Crash & Head", subtitle: "Impact · neck · pupils", iconFilled: false,
            topics: [("Car Crash", "car-crash"), ("Head & Pupils", "head-pupils")]),
    AidPane(id: "bleed", emoji: "🩸", title: "Bleeding", subtitle: "Pressure · tourniquet", iconFilled: true,
            topics: [("Find Bleeding", "find-bleeding"), ("Bad Bleeding", "bad-bleeding"),
                     ("Belt Tourniquet", "belt-tourniquet"), ("Gunshot / Stab", "gunshot-stab")]),
    AidPane(id: "heart", emoji: "❤️", title: "Heart & Airway", subtitle: "CPR · choking", iconFilled: true,
            topics: [("CPR", "cpr"), ("Choking", "choking")]),
    AidPane(id: "shock", emoji: "⚡", title: "Shock", subtitle: "Pale · cold · clammy", iconFilled: false,
            topics: [("Shock", "shock")]),
    AidPane(id: "temp", emoji: "🌡️", title: "Cold & Heat", subtitle: "Notice · warm · cool down", iconFilled: false,
            topics: [("Cold (Hypothermia)", "cold-hypothermia"), ("Heat (Exhaustion & Stroke)", "heat-stroke")]),
    AidPane(id: "seizure", emoji: "🧠", title: "Seizure", subtitle: "Don't restrain · time it", iconFilled: false,
            topics: [("Seizure", "seizure")]),
    AidPane(id: "hospitals", emoji: "🏥", title: "Trauma Hospitals", subtitle: "Nearest Level I/II center", iconFilled: false,
            topics: [("Find Trauma Center", "trauma-hospitals")]),
]

struct AidView: View {
    @State private var openPane: String? = nil
    @State private var activeTopic: AidTopic? = nil

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Roadside Aid")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.redmedDark)
                    Text("Call 911 first. Tap a pane — expand only what you need.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.redmedMuted)

                    PrimaryButton(title: "Call 911") {
                        if let url = URL(string: "tel://911") { UIApplication.shared.open(url) }
                    }

                    HStack(spacing: 8) {
                        PillTag(text: "tap to expand", accent: true)
                        PillTag(text: "911 first", accent: false)
                    }
                    .padding(.bottom, 2)

                    // PANE GRID
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(aidPanes) { pane in
                            let isOpen = openPane == pane.id
                            PaneCard(pane: pane, isOpen: isOpen) { key in
                                if key == nil {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        openPane = isOpen ? nil : pane.id
                                    }
                                } else if let k = key, let topic = aidTopics[k] {
                                    activeTopic = topic
                                }
                            }
                            .gridCellColumns(isOpen ? 2 : 1)
                        }
                    }

                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(Color.redmedBg)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Roadside Aid").font(.system(size: 17, weight: .semibold)).foregroundColor(.redmedDark)
                }
            }
            .sheet(item: $activeTopic) { topic in
                TopicDetailView(topic: topic)
            }
        }
    }
}

// MARK: - Pane Card
struct PaneCard: View {
    let pane: AidPane
    let isOpen: Bool
    let onTap: (String?) -> Void // nil = toggle, string = open topic

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { onTap(nil) } label: {
                HStack(alignment: .top, spacing: 8) {
                    Text(pane.emoji)
                        .font(.system(size: 20))
                        .frame(width: 38, height: 38)
                        .background(isOpen ? Color.redmedAccent : Color.redmedAccent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 11))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(pane.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.redmedDark)
                            .lineLimit(2)
                        if !isOpen {
                            Text(pane.subtitle)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.redmedMuted)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                }
                .padding(13)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(minHeight: 96, alignment: .top)

            if isOpen {
                VStack(spacing: 7) {
                    ForEach(pane.topics, id: \.key) { topic in
                        Button { onTap(topic.key) } label: {
                            HStack {
                                Text(topic.label)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.redmedDark)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(.redmedMuted)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(Color.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.redmedDivider, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
            }
        }
        .background(Color.redmedSurface)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(isOpen ? Color.redmedAccent.opacity(0.28) : Color.redmedDivider, lineWidth: 1)
        )
    }
}

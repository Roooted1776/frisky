import SwiftUI

struct AidPane: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let subtitle: String
    let iconFilled: Bool
    let topics: [(label: String, key: String)]
}

/// Pane chrome only — topic bodies stay in AidTopicCatalog until a topic opens.
enum AidPaneCatalog {
    static let panes: [AidPane] = [
        AidPane(id: "crash", emoji: "🚗", title: "Crash & Head", subtitle: "Impact · neck · spinal", iconFilled: false,
                topics: [("Car Crash", "car-crash"), ("Head & Pupils", "head-pupils"), ("Spinal", "spinal")]),
        AidPane(id: "bleed", emoji: "🩸", title: "Bleeding", subtitle: "Pressure · tourniquet", iconFilled: true,
                topics: [("Find Bleeding", "find-bleeding"), ("Bad Bleeding", "bad-bleeding"),
                         ("Belt Tourniquet", "belt-tourniquet"), ("Gunshot / Stab", "gunshot-stab")]),
        AidPane(id: "breathing", emoji: "🫁", title: "Not Breathing", subtitle: "CPR · airway", iconFilled: true,
                topics: [("CPR", "cpr")]),
        AidPane(id: "heart", emoji: "❤️", title: "Choking", subtitle: "Back blows · Heimlich", iconFilled: true,
                topics: [("Choking", "choking")]),
        AidPane(id: "shock", emoji: "⚡", title: "Shock", subtitle: "Pale · cold · clammy", iconFilled: false,
                topics: [("Shock", "shock")]),
        AidPane(id: "temp", emoji: "🌡️", title: "Burns · Cold · Heat", subtitle: "Cool · warm · cover", iconFilled: false,
                topics: [("Burn Care", "burn-care"), ("Electrical & Chemical", "electrical-chemical-burns"),
                         ("Cold (Hypothermia)", "cold-hypothermia"), ("Heat (Exhaustion & Stroke)", "heat-stroke")]),
        AidPane(id: "seizure", emoji: "🧠", title: "Seizure", subtitle: "Don't restrain · time it", iconFilled: false,
                topics: [("Seizure", "seizure")]),
        AidPane(id: "hospitals", emoji: "🏥", title: "Nearby Hospitals", subtitle: "MapKit emergency POIs", iconFilled: false,
                topics: [("Find Nearby Hospitals", "trauma-hospitals")]),
    ]

    #if DEBUG
    /// Pane keys and topic bodies live in separate catalogs — keep them in lockstep.
    /// Missing catalog entry → topic tap silently no-ops in AidView.
    static func assertTopicCoverage() {
        for pane in panes {
            for topic in pane.topics {
                assert(
                    AidTopicCatalog.topics[topic.key] != nil,
                    "Aid pane '\(pane.id)' lists '\(topic.key)' with no AidTopicCatalog entry"
                )
            }
        }
    }
    #endif
}

struct AidView: View {
    @Environment(\.isScannerSession) private var isScannerSession
    @State private var openPane: String? = nil
    @State private var activeTopic: AidTopic? = nil

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    // Brand wordmark in place of the old "Roadside Aid" hero title
                    Image("BrandWordmark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 42)
                        .accessibilityLabel("RedMed")
                        .padding(.top, 2)

                    Text("expand pane - tap a pane")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.redmedMuted)

                    HStack(spacing: 8) {
                        PillTag(text: "expand pane - tap a pane", accent: true)
                    }
                    .padding(.bottom, 2)

                    // PANE GRID
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(AidPaneCatalog.panes) { pane in
                            let isOpen = openPane == pane.id
                            PaneCard(pane: pane, isOpen: isOpen) { key in
                                if key == nil {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        openPane = isOpen ? nil : pane.id
                                    }
                                } else if let k = key, let topic = AidTopicCatalog.topics[k] {
                                    activeTopic = topic
                                }
                            }
                            .gridCellColumns(isOpen ? 2 : 1)
                        }

                        // Under panes, above quote — full-width like an open pane.
                        CrashSurvivalCancelCard()
                            .gridCellColumns(2)
                    }

                    // Quote moved from RedMed (main) tab — sits below the panes
                    Text("\"Control your fear. Control the moment.\nYou have what it takes to save a life.\"")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.redmedDark)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                        .padding(.bottom, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 24)
            }
            .background(Color.redmedBg)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.redmedBg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                // No "Roadside Aid" principal — BrandWordmark is the hero brand signal.
                // Keep main's matching redmedBg toolbar chrome.
                if isScannerSession {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ScannerCloseButton()
                    }
                }
            }
            .sheet(item: $activeTopic) { topic in
                TopicDetailView(topic: topic)
            }
            .task {
                await Task.yield()
                AidTopicCatalog.warmUp()
                #if DEBUG
                AidPaneCatalog.assertTopicCoverage()
                #endif
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
                            .foregroundColor(.redmedAccent)
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    isOpen ? Color.redmedAccent.opacity(0.28) : Color.redmedDark.opacity(0.08),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
    }
}

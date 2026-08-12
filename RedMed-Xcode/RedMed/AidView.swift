import SwiftUI

struct AidPane: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let iconFilled: Bool
    let topics: [(label: String, key: String)]
}

/// Pane chrome only — topic bodies stay in AidTopicCatalog until a topic opens.
enum AidPaneCatalog {
    static let panes: [AidPane] = [
        AidPane(id: "crash", emoji: "🚗", title: "Crash & Head", iconFilled: false,
                topics: [("Car Crash", "car-crash"), ("Head & Pupils", "head-pupils"), ("Spinal", "spinal")]),
        AidPane(id: "bleed", emoji: "🩸", title: "Bleeding", iconFilled: true,
                topics: [("Find Bleeding", "find-bleeding"), ("Bad Bleeding", "bad-bleeding"),
                         ("Belt Tourniquet", "belt-tourniquet"), ("Gunshot / Stab", "gunshot-stab")]),
        AidPane(id: "breathing", emoji: "🫁", title: "Not Breathing", iconFilled: true,
                topics: [("CPR", "cpr")]),
        AidPane(id: "heart", emoji: "❤️", title: "Choking", iconFilled: true,
                topics: [("Choking", "choking")]),
        AidPane(id: "shock", emoji: "⚡", title: "Shock", iconFilled: false,
                topics: [("Shock", "shock")]),
        AidPane(id: "temp", emoji: "🌡️", title: "Burns · Cold · Heat", iconFilled: false,
                topics: [("Burn Care", "burn-care"), ("Electrical & Chemical", "electrical-chemical-burns"),
                         ("Cold (Hypothermia)", "cold-hypothermia"), ("Heat (Exhaustion & Stroke)", "heat-stroke")]),
        AidPane(id: "seizure", emoji: "🧠", title: "Seizure", iconFilled: false,
                topics: [("Seizure", "seizure")]),
        AidPane(id: "hospitals", emoji: "🏥", title: "Nearby Hospitals", iconFilled: false,
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

    var body: some View {
        // Full-width accordion — life-saving: big targets, text always fits, no
        // 2-col reflow when a pane opens. Same pattern as passerby get.html Aid.
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ZStack(alignment: .topTrailing) {
                        Image("BrandWordmark")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 42)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityLabel("RedMed")
                            .padding(.trailing, isScannerSession ? 56 : 0)

                        if isScannerSession {
                            ScannerBackButton()
                                .padding(.top, 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(AidPaneCatalog.panes) { pane in
                            let isOpen = openPane == pane.id
                            PaneCard(pane: pane, isOpen: isOpen) { key in
                                if key == nil {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        openPane = isOpen ? nil : pane.id
                                    }
                                } else if let k = key, let topic = AidTopicCatalog.topics[k] {
                                    activeTopic = topic
                                }
                            }
                        }

                        CrashSurvivalCancelCard()
                    }

                    // Prayer sits toward the bottom when panes leave spare height.
                    Spacer(minLength: 28)

                    Text("\"Control your fear. Control the moment.\nYou have what it takes to save a life.\"")
                        .font(.system(size: 8, weight: .regular))
                        .italic()
                        .foregroundColor(.redmedMuted.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 28)

                    Text(AppConfig.Satellite.localOnlyLine)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 24)
                .frame(minHeight: geo.size.height, alignment: .top)
            }
        }
        .background(Color.redmedBg)
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

// MARK: - Pane Card
struct PaneCard: View {
    let pane: AidPane
    let isOpen: Bool
    let onTap: (String?) -> Void // nil = toggle, string = open topic

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { onTap(nil) } label: {
                HStack(alignment: .center, spacing: 12) {
                    Text(pane.emoji)
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        .background(isOpen ? Color.redmedAccent : Color.redmedAccent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.chipRadius))
                        .accessibilityHidden(true)

                    // Title + emoji only — red chrome, scales to fit the pane.
                    Text(pane.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.redmedAccent)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .frame(width: 28, height: 28)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(pane.title)
            .accessibilityHint(isOpen ? "Collapse" : "Expand topics")

            if isOpen {
                VStack(spacing: 8) {
                    ForEach(pane.topics, id: \.key) { topic in
                        Button { onTap(topic.key) } label: {
                            HStack(alignment: .center, spacing: 10) {
                                Text(topic.label)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.redmedAccent)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.75)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .layoutPriority(1)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.redmedAccent.opacity(0.55))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: RedMedChrome.boxRadius)
                                    .strokeBorder(Color.redmedDivider, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(topic.label)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.redmedSurface)
        .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius))
        .overlay(
            RoundedRectangle(cornerRadius: RedMedChrome.boxRadius)
                .strokeBorder(
                    isOpen ? Color.redmedAccent.opacity(0.35) : Color.redmedDivider,
                    lineWidth: 1
                )
        )
    }
}

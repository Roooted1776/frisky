import SwiftUI

struct AidPane: Identifiable {
    let id: String
    let emoji: String
    let title: String
    let topics: [(label: String, key: String)]
}

/// Pane chrome only — topic bodies stay in AidTopicCatalog until a topic opens.
enum AidPaneCatalog {
    static let panes: [AidPane] = [
        AidPane(id: "hospitals", emoji: "🏥", title: "Nearby Hospitals",
                topics: [("Find Nearby Hospitals", "trauma-hospitals")]),
        AidPane(id: "crash", emoji: "🚗", title: "Crash & Head",
                topics: [("Car Crash", "car-crash"), ("Head & Pupils", "head-pupils"), ("Spinal", "spinal")]),
        AidPane(id: "bleed", emoji: "🩸", title: "Bleeding",
                topics: [("Find Bleeding", "find-bleeding"), ("Bad Bleeding", "bad-bleeding"),
                         ("Belt Tourniquet", "belt-tourniquet"), ("Gunshot / Stab", "gunshot-stab")]),
        AidPane(id: "breathing", emoji: "🫁", title: "Not Breathing",
                topics: [("CPR", "cpr")]),
        AidPane(id: "choking", emoji: "❤️", title: "Choking",
                topics: [("Choking", "choking")]),
        AidPane(id: "shock", emoji: "⚡", title: "Shock",
                topics: [("Shock", "shock")]),
        AidPane(id: "temp", emoji: "🌡️", title: "Burns · Cold · Heat",
                topics: [("Burn Care", "burn-care"), ("Electrical & Chemical", "electrical-chemical-burns"),
                         ("Cold (Hypothermia)", "cold-hypothermia"), ("Heat (Exhaustion & Stroke)", "heat-stroke")]),
        AidPane(id: "seizure", emoji: "🧠", title: "Seizure",
                topics: [("Seizure", "seizure")]),
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
        // 2-col reflow when a pane opens. Same pattern as passerby tapper.html Aid.
        // No page header / pane BrandWordmark — content-first, nothing hanging.
        // Help is a sibling row (same as RedMed) so Aid panes sit below it.
        VStack(spacing: 0) {
            PageHelpChrome()

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(AidPaneCatalog.panes) { pane in
                            let isOpen = openPane == pane.id
                            PaneCard(pane: pane, isOpen: isOpen) { key in
                                if key == nil {
                                    RedMedHaptics.selection()
                                    var t = Transaction()
                                    t.animation = nil
                                    withTransaction(t) {
                                        openPane = isOpen ? nil : pane.id
                                    }
                                } else if let k = key, let topic = AidTopicCatalog.topics[k] {
                                    RedMedHaptics.light()
                                    activeTopic = topic
                                }
                            }
                            .equatable()
                        }

                        CrashSurvivalCancelCard()
                    }

                    Text(AppConfig.AidCopy.referenceDisclaimer)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)
                        .padding(.top, 8)

                    // Quiet prayer — owner Aid only (not scanner / passerby shells).
                    Spacer(minLength: 28)

                    if !isScannerSession {
                        Text("\"\(AppConfig.QuietPrayer.text)\"")
                            .font(.system(size: AppConfig.QuietPrayer.fontSize, weight: .regular))
                            .italic()
                            .foregroundColor(.redmedMuted.opacity(0.72))
                            .multilineTextAlignment(.center)
                            .lineSpacing(1)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 28)
                    }

                    Text(AppConfig.Satellite.localOnlyLine)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }
                .padding(.horizontal, RedMedChrome.pagePadX)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.visible)
        }
        .sheet(item: $activeTopic) { topic in
            TopicDetailView(topic: topic)
                .presentationBackground(Color.redmedBg)
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
struct PaneCard: View, Equatable {
    let pane: AidPane
    let isOpen: Bool
    let onTap: (String?) -> Void // nil = toggle, string = open topic

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.pane.id == rhs.pane.id && lhs.isOpen == rhs.isOpen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { onTap(nil) } label: {
                HStack(alignment: .center, spacing: 12) {
                    Text(pane.emoji)
                        .font(.system(size: 22))
                        .frame(width: 44, height: 44)
                        // Cream at rest, solid accent while open — same for every pane.
                        .background(isOpen ? Color.redmedAccent : Color.redmedAccent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.chipRadius))
                        .accessibilityHidden(true)

                    Text(pane.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.redmedAccent)
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                        .frame(width: 28, height: 28)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(RedMedPressStyle(scale: 0.985, haptic: nil))
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
                            .background(Color.redmedSurface)
                            .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius))
                        }
                        .buttonStyle(RedMedPressStyle(scale: 0.98, haptic: nil))
                        .accessibilityLabel(topic.label)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            isOpen ? Color.redmedAccent.opacity(0.03) : Color.redmedSurface
        )
        .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius))
        .shadow(color: RedMedChrome.cardShadow, radius: 8, y: 3)
        .compositingGroup()
        .transaction { $0.animation = nil }
    }
}

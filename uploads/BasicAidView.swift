import SwiftUI

struct BasicAidView: View {
    @Environment(\.layoutMetrics) private var layout

    @State private var openPaneId: String?
    @State private var activeTopic: FirstAidTopic?

    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: layout.s(10)),
            GridItem(.flexible(), spacing: layout.s(10))
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: layout.s(12)) {
                    Text("Roadside Aid")
                        .font(.system(size: layout.s(22), weight: .bold))
                        .foregroundStyle(AppTheme.ink)
                    Text("Call 911 first. Tap a pane — expand only what you need.")
                        .font(.system(size: layout.s(12), weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    Call911Button()

                    HStack(spacing: layout.s(8)) {
                        DesignPillTag(text: "tap to expand", accent: true)
                        DesignPillTag(text: "911 first", accent: false)
                    }
                    .padding(.bottom, layout.s(2))

                    LazyVGrid(columns: columns, spacing: layout.s(10)) {
                        ForEach(AidPaneLibrary.panes) { pane in
                            AidPaneCard(
                                pane: pane,
                                isOpen: openPaneId == pane.id,
                                activeTopic: $activeTopic,
                                onToggle: {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                        openPaneId = openPaneId == pane.id ? nil : pane.id
                                    }
                                }
                            )
                            .gridCellColumns(openPaneId == pane.id ? 2 : 1)
                        }
                    }

                    Text(Self.aidPrayer)
                        .font(.system(size: layout.s(12)))
                        .italic()
                        .foregroundStyle(Color(red: 0.659, green: 0.639, blue: 0.620))
                        .multilineTextAlignment(.center)
                        .lineSpacing(layout.s(4))
                        .frame(maxWidth: .infinity)
                        .padding(.top, layout.s(21)) // lowered 21pt from grid
                        .padding(.bottom, layout.screenBottom)
                }
                .padding(.horizontal, layout.screenPad)
                .padding(.top, layout.s(10))
                .reactiveScrollTrack()
            }
            .scrollIndicators(.visible, axes: .vertical)
            .background(AppTheme.pageBg)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Roadside Aid")
                        .font(.system(size: layout.s(17), weight: .semibold))
                        .foregroundStyle(AppTheme.ink)
                }
            }
            .sheet(item: $activeTopic) { topic in
                FirstAidDetailView(topic: topic)
                    .withLayoutMetrics()
            }
        }
    }

    private static let aidPrayer =
        "God of mercy, hold the injured in your care.\nGive strength to those who help, and wisdom to every choice made here.\nBring healing, comfort, and safe passage until help arrives.\nAmen."
}

private struct AidPaneCard: View {
    @Environment(\.layoutMetrics) private var layout

    let pane: AidPane
    let isOpen: Bool
    @Binding var activeTopic: FirstAidTopic?
    let onToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: layout.s(10)) {
                    Text(pane.emoji)
                        .font(.system(size: layout.s(22)))
                        .frame(width: layout.s(40), height: layout.s(40))
                        .background(isOpen ? AppTheme.accent : AppTheme.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: layout.s(12), style: .continuous))

                    VStack(alignment: .leading, spacing: layout.s(3)) {
                        Text(pane.title)
                            .font(.system(size: layout.s(14), weight: .bold))
                            .foregroundStyle(AppTheme.ink)
                            .multilineTextAlignment(.leading)
                        if !isOpen {
                            Text(pane.blurb)
                                .font(.system(size: layout.s(12), weight: .semibold))
                                .foregroundStyle(AppTheme.muted)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                        .font(.system(size: layout.s(12), weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .padding(layout.s(14))
                .frame(maxWidth: .infinity, minHeight: layout.aidPaneMinHeight, alignment: .topLeading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isOpen {
                VStack(spacing: layout.s(7)) {
                    ForEach(pane.topics) { topic in
                        Button {
                            activeTopic = topic
                        } label: {
                            HStack {
                                Text(topic.title)
                                    .font(.system(size: layout.s(14), weight: .semibold))
                                    .foregroundStyle(AppTheme.ink)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: layout.s(11), weight: .semibold))
                                    .foregroundStyle(AppTheme.muted)
                            }
                            .padding(.horizontal, layout.s(12))
                            .padding(.vertical, layout.s(10))
                            .background(AppTheme.secondarySurface)
                            .clipShape(RoundedRectangle(cornerRadius: layout.s(12), style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: layout.s(12), style: .continuous)
                                    .stroke(AppTheme.line, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, layout.s(10))
                .padding(.bottom, layout.s(14))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(AppTheme.cardBg)
        .clipShape(RoundedRectangle(cornerRadius: layout.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.cardRadius, style: .continuous)
                .stroke(isOpen ? AppTheme.accent.opacity(0.28) : AppTheme.line, lineWidth: 1)
        )
    }
}

#Preview {
    BasicAidView()
        .withLayoutMetrics()
}

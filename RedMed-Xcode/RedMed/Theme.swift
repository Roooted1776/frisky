import SwiftUI

/// Shared springs / fades for owner + scanner chrome. Keep short — presence, not noise.
enum RedMedMotion {
    /// Tab highlight, Aid chevron, SOS chrome.
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.82)
    /// Pane expand / collapse.
    static let expand = Animation.spring(response: 0.38, dampingFraction: 0.86)
    /// Opacity keep-alive tab crossfade.
    static let tabFade = Animation.easeInOut(duration: 0.18)
    /// Lock → unlocked / list value swaps.
    static let soft = Animation.easeInOut(duration: 0.22)
}

/// Press scale for CTAs and chrome — reactive without fighting scroll.
struct RedMedPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var haptic: (() -> Void)? = { RedMedHaptics.light() }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(RedMedMotion.snappy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { haptic?() }
            }
    }
}

extension Color {
    static let redmedAccent   = Color(red: 0.882, green: 0.114, blue: 0.282) // #e11d48
    static let redmedBg       = Color(red: 1.000, green: 0.969, blue: 0.969) // #fff7f7
    /// Heading / primary ink — same on owner chrome + passerby `--dark` / legal `--text`.
    static let redmedDark     = Color(red: 0.129, green: 0.122, blue: 0.122) // #211F1F
    static let redmedMuted    = Color(red: 0.471, green: 0.443, blue: 0.424) // #78716c
    /// Cream-lift panel fill — not pure white (white boxes on `redmedBg`).
    static let redmedSurface  = Color(red: 1.000, green: 0.953, blue: 0.957) // #fff3f4
    /// Row / chip hairline — same 8% ink as passerby dividers / legal `--border`.
    static let redmedDivider  = Color(red: 0.129, green: 0.122, blue: 0.122).opacity(0.08)
    /// Soft top wash — pairs with passerby body gradient.
    static let redmedWash     = Color(red: 1.000, green: 0.910, blue: 0.922) // #ffe8eb
}

/// Cream page with rose wash only (fill color — no BrandLogo).
/// Lock shell is the same flat cream; passerby tapper matches this fill.
struct RedMedPageBackground: View {
    var body: some View {
        ZStack {
            Color.redmedBg
            RadialGradient(
                colors: [Color.redmedWash.opacity(0.85), Color.redmedBg.opacity(0)],
                center: .top,
                startRadius: 20,
                endRadius: 420
            )
            .frame(maxHeight: 520)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.redmedMuted)
            .kerning(0.6)
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
    }
}

struct CardRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.redmedMuted)
            Spacer()
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(value.isEmpty ? .redmedMuted.opacity(0.4) : .redmedDark)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }
}

struct PillTag: View {
    let text: String
    let accent: Bool

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .kerning(0.8)
            .foregroundColor(accent ? .redmedAccent : .redmedMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: RedMedChrome.chipRadius)
                    .fill(accent ? Color.redmedAccent.opacity(0.1) : Color.redmedSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RedMedChrome.chipRadius)
                            .strokeBorder(accent ? Color.clear : Color.redmedDivider, lineWidth: 1)
                    )
            )
    }
}

struct PrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button {
            RedMedHaptics.medium()
            action()
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(colors: [Color(red:1, green:0.447, blue:0.537), .redmedAccent],
                                   startPoint: .top, endPoint: .bottom)
                )
                .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius))
                .shadow(color: RedMedChrome.accentShadow, radius: 10, y: 5)
        }
        .buttonStyle(RedMedPressStyle(haptic: nil))
    }
}

struct SecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button {
            RedMedHaptics.light()
            action()
        } label: {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 14)) }
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.redmedDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.redmedSurface)
            .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius))
            .overlay(
                RoundedRectangle(cornerRadius: RedMedChrome.boxRadius)
                    .strokeBorder(Color.redmedDivider, lineWidth: 1)
            )
            .shadow(color: RedMedChrome.cardShadow, radius: 6, y: 2)
        }
        .buttonStyle(RedMedPressStyle(haptic: nil))
    }
}

/// Trailing chrome text — owner **Help** / **Edit** / NFC **Preview**, scanner **Back**, Aid topic **Back**.
/// Accent red text only — no chip / box fill (plain link over the HTML shell).
struct ChromeTextAction: View {
    let title: String
    var weight: Font.Weight = .regular
    let action: () -> Void

    var body: some View {
        Button {
            RedMedHaptics.light()
            action()
        } label: {
            Text(title)
                .font(.system(size: RedMedChrome.chromeActionSize, weight: weight))
                .foregroundColor(.redmedAccent)
                .kerning(-0.2)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .padding(.horizontal, 4)
                .padding(.vertical, 6)
        }
        .buttonStyle(RedMedPressStyle(scale: 0.96, haptic: nil))
        .tint(.redmedAccent)
        .fixedSize()
    }
}

/// Shared top bar for owner Help / Edit / Preview full-screen modals.
/// Equal leading/trailing slots keep the title centered and the three pages even.
struct OwnerModalChrome<Trailing: View>: View {
    let title: String
    let leadingTitle: String
    let leadingWeight: Font.Weight
    let leadingAction: () -> Void
    let trailing: Trailing

    init(
        title: String,
        leadingTitle: String,
        leadingWeight: Font.Weight = .regular,
        leadingAction: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.leadingTitle = leadingTitle
        self.leadingWeight = leadingWeight
        self.leadingAction = leadingAction
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button(action: {
                    RedMedHaptics.light()
                    leadingAction()
                }) {
                    Text(leadingTitle)
                        .font(.system(size: RedMedChrome.modalActionSize, weight: leadingWeight))
                        .foregroundColor(.redmedAccent)
                        .frame(minWidth: RedMedChrome.modalSideMinWidth, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(RedMedPressStyle(scale: 0.96, haptic: nil))

                Spacer(minLength: 8)

                Text(title)
                    .font(RedMedChrome.navTitleFont)
                    .foregroundColor(.redmedDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 8)

                trailing
                    .frame(minWidth: RedMedChrome.modalSideMinWidth, alignment: .trailing)
            }
            .padding(.horizontal, RedMedChrome.pagePadX)
            .frame(height: RedMedChrome.modalBarHeight)

            Rectangle()
                .fill(Color.redmedDivider)
                .frame(height: 1)
        }
        // No solid fill — page `RedMedPageBackground` (same cream as body) shows through.
    }
}

extension OwnerModalChrome where Trailing == EmptyView {
    /// Leading-only bar (Preview Back / Help Done) — empty trailing keeps title centered
    /// via the shared `modalSideMinWidth` frame on the trailing slot.
    init(title: String, leadingTitle: String, leadingWeight: Font.Weight = .regular, leadingAction: @escaping () -> Void) {
        self.init(
            title: title,
            leadingTitle: leadingTitle,
            leadingWeight: leadingWeight,
            leadingAction: leadingAction,
            trailing: { EmptyView() }
        )
    }
}

/// Accent text button for the trailing slot of `OwnerModalChrome` (Edit Save).
struct OwnerModalTrailingAction: View {
    let title: String
    var weight: Font.Weight = .bold
    let action: () -> Void

    var body: some View {
        Button(action: {
            RedMedHaptics.light()
            action()
        }) {
            Text(title)
                .font(.system(size: RedMedChrome.modalActionSize, weight: weight))
                .foregroundColor(.redmedAccent)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(RedMedPressStyle(scale: 0.96, haptic: nil))
    }
}

/// Inline nav titles (topic detail). Semibold 17 accent beside ChromeTextAction (18 regular).
/// Box radius is shared by owner + scanner cards / CTAs (square-ish, not capsules).
enum RedMedChrome {
    static let navTitleFont: Font = .system(size: 17, weight: .semibold)
    /// Help · Edit · Preview chrome links over the shell.
    static let chromeActionSize: CGFloat = 18
    /// Cancel / Done / Back / Save inside owner modals — same size on all three.
    static let modalActionSize: CGFloat = 17
    static let modalBarHeight: CGFloat = 52
    static let modalSideMinWidth: CGFloat = 64
    static let boxRadius: CGFloat = 10
    static let chipRadius: CGFloat = 7
    /// Brand mark is a circular disc — always `Circle()`, never a rounded rect.
    static let logoRadius: CGFloat = 0
    /// Tapper / empty YOU-card BrandLogo diameter (`--logo` matches).
    static let logoSize: CGFloat = 72
    /// BrandWordmark lockup on NFC / topic pages (Aid + 911 are content-first).
    static let wordmarkHeight: CGFloat = 42
    static let pagePadX: CGFloat = 16
    static let wordmarkTop: CGFloat = 6
    static let wordmarkBottom: CGFloat = 4
    static let cardShadow = Color.black.opacity(0.045)
    static let accentShadow = Color.redmedAccent.opacity(0.18)
}

/// Pinned BrandWordmark row — NFC / topic pages (not Aid or 911).
struct BrandWordmarkHeader<Trailing: View>: View {
    var top: CGFloat = RedMedChrome.wordmarkTop
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image("BrandWordmark")
                .resizable()
                .scaledToFit()
                .frame(height: RedMedChrome.wordmarkHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("RedMed")
                .layoutPriority(1)
            trailing()
        }
        .padding(.horizontal, RedMedChrome.pagePadX)
        .padding(.top, top)
        .padding(.bottom, RedMedChrome.wordmarkBottom)
    }
}

extension BrandWordmarkHeader where Trailing == EmptyView {
    init(top: CGFloat = RedMedChrome.wordmarkTop) {
        self.top = top
        self.trailing = { EmptyView() }
    }
}

extension View {
    /// Surface card chrome used on RedMed / 911 / Aid / NFC (owner + scanner).
    /// No outer stroke — fill + radius + optional shadow only.
    func redmedBox(elevated: Bool = true) -> some View {
        self
            .background(Color.redmedSurface)
            .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius))
            .shadow(color: elevated ? RedMedChrome.cardShadow : .clear, radius: 8, y: 3)
    }
}

/// Wraps subviews onto new lines; each child keeps its intrinsic width
/// so short labels (Percocet) stay smaller than long ones (Dextroamphetamine).
/// Chips wider than the row are capped and remeasured so text wraps
/// instead of clipping off-screen.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    struct Cache {
        var width: CGFloat = .nan
        var origins: [CGPoint] = []
        var sizes: [CGSize] = []
        var size: CGSize = .zero
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        // Always recompute here — placeSubviews reuses this pass's result.
        cache = arrange(proposal: proposal, subviews: subviews)
        return cache.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        let maxWidth = proposal.width ?? .infinity
        if cache.width != maxWidth || cache.origins.count != subviews.count {
            cache = arrange(proposal: proposal, subviews: subviews)
        }
        for index in subviews.indices {
            let size = cache.sizes[index]
            subviews[index].place(
                at: CGPoint(x: bounds.minX + cache.origins[index].x, y: bounds.minY + cache.origins[index].y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> Cache {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        origins.reserveCapacity(subviews.count)
        var sizes: [CGSize] = []
        sizes.reserveCapacity(subviews.count)
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widthUsed: CGFloat = 0

        for subview in subviews {
            let ideal = subview.sizeThatFits(.unspecified)
            let cappedWidth: CGFloat = {
                guard maxWidth.isFinite else { return ideal.width }
                return min(ideal.width, maxWidth)
            }()

            // Remeasure when capped so multiline text gets the right height.
            let size: CGSize = {
                if cappedWidth < ideal.width - 0.5 {
                    return subview.sizeThatFits(ProposedViewSize(width: cappedWidth, height: nil))
                }
                return CGSize(width: cappedWidth, height: ideal.height)
            }()

            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            origins.append(CGPoint(x: x, y: y))
            sizes.append(size)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            widthUsed = max(widthUsed, x - spacing)
        }

        return Cache(
            width: maxWidth,
            origins: origins,
            sizes: sizes,
            size: CGSize(width: widthUsed, height: y + rowHeight)
        )
    }
}

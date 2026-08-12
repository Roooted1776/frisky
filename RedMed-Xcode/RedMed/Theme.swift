import SwiftUI

extension Color {
    static let redmedAccent   = Color(red: 0.882, green: 0.114, blue: 0.282) // #e11d48
    static let redmedBg       = Color(red: 1.000, green: 0.969, blue: 0.969) // #fff7f7
    static let redmedDark     = Color(red: 0.110, green: 0.098, blue: 0.086) // #1c1917
    static let redmedMuted    = Color(red: 0.471, green: 0.443, blue: 0.424) // #78716c
    static let redmedSurface  = Color.white.opacity(0.92)
    /// Card + hairline stroke — same 8% ink as passerby `.card` / legal `--border`.
    static let redmedDivider  = Color(red: 0.110, green: 0.098, blue: 0.086).opacity(0.08)
}

struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.redmedMuted)
            .kerning(0.6)
            .padding(.horizontal, 4)
            .padding(.bottom, 5)
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
                    .fill(accent ? Color.redmedAccent.opacity(0.1) : Color.white.opacity(0.7))
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
        Button(action: action) {
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
                .shadow(color: Color.redmedAccent.opacity(0.28), radius: 7, y: 4)
        }
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
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon { Image(systemName: icon).font(.system(size: 14)) }
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.redmedDark)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.82))
            .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius))
            .overlay(
                RoundedRectangle(cornerRadius: RedMedChrome.boxRadius)
                    .strokeBorder(Color.redmedDivider, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
    }
}

/// Trailing chrome text — owner **Edit**, scanner **Back**, Aid topic **Back**.
/// Plain style: accent red text, no fill pill (page shows through). One red, one size.
struct ChromeTextAction: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 18, weight: .regular))
                .foregroundColor(.redmedAccent)
                .kerning(-0.2)
        }
        .buttonStyle(.plain)
    }
}

/// Inline nav titles (Find Help, topic). Semibold 17 accent — pairs with ChromeTextAction.
/// Box radius is shared by owner + scanner cards / CTAs (square-ish, not capsules).
enum RedMedChrome {
    static let navTitleFont: Font = .system(size: 17, weight: .semibold)
    static let boxRadius: CGFloat = 8
    static let chipRadius: CGFloat = 6
    static let logoRadius: CGFloat = 10
}

extension View {
    /// Surface card chrome used on RedMed / 911 / Aid / NFC (owner + scanner).
    /// `strokeBorder` keeps the full 1pt hairline inside the shape (`.stroke` half-clips).
    func redmedBox(strokeOpacity: Double = 1) -> some View {
        self
            .background(Color.redmedSurface)
            .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius))
            .overlay(
                RoundedRectangle(cornerRadius: RedMedChrome.boxRadius)
                    .strokeBorder(Color.redmedDivider.opacity(strokeOpacity), lineWidth: 1)
            )
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

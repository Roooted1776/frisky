import SwiftUI
import UIKit

/// Shared springs / fades for owner + scanner chrome. Keep short — presence, not noise.
enum RedMedMotion {
    /// Tab highlight, Aid chevron, SOS chrome, press scale.
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.82)
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
    static let redmedDark     = Color(red: 0.110, green: 0.098, blue: 0.086) // #1c1917
    static let redmedMuted    = Color(red: 0.471, green: 0.443, blue: 0.424) // #78716c
    /// Cream-lift panel fill — not pure white (white boxes on `redmedBg`).
    static let redmedSurface  = Color(red: 1.000, green: 0.953, blue: 0.957) // #fff3f4
    /// Row / chip hairline — same 8% ink as passerby dividers / legal `--border`.
    static let redmedDivider  = Color(red: 0.110, green: 0.098, blue: 0.086).opacity(0.08)
    /// Soft top wash — pairs with passerby body gradient.
    static let redmedWash     = Color(red: 1.000, green: 0.910, blue: 0.922) // #ffe8eb
}

/// Cream page with rose wash only (fill color — no BrandLogo).
/// Lock front (`LockEntryPage`) is static `redmedBg` only; passerby tapper
/// matches cream fill.
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

/// Paints the UIWindow cream so UIKit transition gaps are never system white.
struct CreamWindowBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            let cream = UIColor(Color.redmedBg)
            view.window?.backgroundColor = cream
            view.window?.rootViewController?.view.backgroundColor = cream
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        let cream = UIColor(Color.redmedBg)
        uiView.window?.backgroundColor = cream
        uiView.window?.rootViewController?.view.backgroundColor = cream
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

struct PrimaryButton: View {
    let title: String
    var disabled: Bool = false
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
                .shadow(color: disabled ? .clear : RedMedChrome.accentShadow, radius: 10, y: 5)
        }
        .buttonStyle(RedMedPressStyle(haptic: nil))
        .disabled(disabled)
        .opacity(disabled ? 0.48 : 1)
        .accessibilityAddTraits(.isButton)
    }
}

/// Full-width CTA from the original Face ID unlock dock — gradient fill,
/// continuous corners, white hairline. Face page **Proceed** still uses this.
/// Owner RedMed tab no longer mounts a bottom Help dock.
struct UnlockScreenButton: View {
    let title: String
    var disabled: Bool = false
    var accessibilityHintText: String? = nil
    let action: () -> Void

    var body: some View {
        Button {
            RedMedHaptics.medium()
            action()
        } label: {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background {
                    RoundedRectangle(cornerRadius: RedMedChrome.unlockButtonRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1, green: 0.447, blue: 0.537).opacity(0.75),
                                    Color.redmedAccent.opacity(0.75)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: RedMedChrome.unlockButtonRadius, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.32), lineWidth: 1)
                        }
                        .shadow(
                            color: disabled ? .clear : RedMedChrome.accentShadow,
                            radius: 12,
                            y: 6
                        )
                }
        }
        .buttonStyle(RedMedPressStyle(haptic: nil))
        .disabled(disabled)
        .opacity(disabled ? 0.48 : 1)
        .accessibilityLabel(title)
        .accessibilityHint(disabled ? "Waiting for Face ID" : (accessibilityHintText ?? ""))
        .accessibilityAddTraits(.isButton)
    }
}

/// Trailing chrome text — owner **Edit**, NFC Preview **Back**, scanner **Back**, Aid topic **Back**.
/// Help on 911 / Aid / NFC / Edit stays chrome text, not a bottom dock.
/// No Help on the Face ID lock shell or the owner RedMed tab itself.
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

/// One type size / height for Cancel · Help · Save · Done in owner modals.
struct OwnerModalBarButton: View {
    let title: String
    var weight: Font.Weight = .regular
    var alignment: Alignment = .center
    /// Equal-width Edit columns. Off for Help Done so the title stays centered.
    var fillWidth: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            RedMedHaptics.light()
            action()
        } label: {
            Text(title)
                .font(.system(size: RedMedChrome.modalActionSize, weight: weight))
                .foregroundColor(.redmedAccent)
                .kerning(-0.2)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .frame(
                    maxWidth: fillWidth ? .infinity : nil,
                    maxHeight: .infinity,
                    alignment: alignment
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(RedMedPressStyle(scale: 0.96, haptic: nil))
        .tint(.redmedAccent)
    }
}

/// Shared top bar for owner Help full-screen modal (Done + title).
/// Edit uses `OwnerModalActionBar` (Cancel · Help · Save on one baseline).
/// NFC Preview uses main-page `ChromeTextAction` Back instead.
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
                OwnerModalBarButton(
                    title: leadingTitle,
                    weight: leadingWeight,
                    alignment: .leading,
                    action: leadingAction
                )
                .frame(minWidth: RedMedChrome.modalSideMinWidth, alignment: .leading)

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

/// Edit modal bar: Cancel (left), Help (center), Save (right).
/// Same type size and bar height so Help stays level with both actions.
struct OwnerModalActionBar<Center: View>: View {
    let leadingTitle: String
    var leadingWeight: Font.Weight = .regular
    let leadingAction: () -> Void
    let trailingTitle: String
    var trailingWeight: Font.Weight = .bold
    let trailingAction: () -> Void
    let center: Center

    init(
        leadingTitle: String,
        leadingWeight: Font.Weight = .regular,
        leadingAction: @escaping () -> Void,
        trailingTitle: String,
        trailingWeight: Font.Weight = .bold,
        trailingAction: @escaping () -> Void,
        @ViewBuilder center: () -> Center
    ) {
        self.leadingTitle = leadingTitle
        self.leadingWeight = leadingWeight
        self.leadingAction = leadingAction
        self.trailingTitle = trailingTitle
        self.trailingWeight = trailingWeight
        self.trailingAction = trailingAction
        self.center = center()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                OwnerModalBarButton(
                    title: leadingTitle,
                    weight: leadingWeight,
                    alignment: .leading,
                    fillWidth: true,
                    action: leadingAction
                )
                center
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                OwnerModalBarButton(
                    title: trailingTitle,
                    weight: trailingWeight,
                    alignment: .trailing,
                    fillWidth: true,
                    action: trailingAction
                )
            }
            .padding(.horizontal, RedMedChrome.pagePadX)
            .frame(height: RedMedChrome.modalBarHeight)

            Rectangle()
                .fill(Color.redmedDivider)
                .frame(height: 1)
        }
    }
}

extension OwnerModalChrome where Trailing == EmptyView {
    /// Leading-only bar (Help Done) — empty trailing keeps title centered
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

/// Inline nav titles (topic detail). Semibold 17 accent beside ChromeTextAction (18 regular).
/// Box radius is shared by owner + scanner cards / CTAs (square-ish, not capsules).
enum RedMedChrome {
    static let navTitleFont: Font = .system(size: 17, weight: .semibold)
    /// Help / Edit (RedMed), Help on 911 / Aid / NFC, Back (Preview / scanner / topic).
    static let chromeActionSize: CGFloat = 18
    /// Cancel / Help / Save / Done inside owner Help · Edit modals.
    static let modalActionSize: CGFloat = 17
    static let modalBarHeight: CGFloat = 52
    static let modalSideMinWidth: CGFloat = 64
    static let boxRadius: CGFloat = 10
    static let chipRadius: CGFloat = 7
    /// Proceed CTA — continuous pill-ish.
    static let unlockButtonRadius: CGFloat = 20
    /// Small lock-load medical mark (not BrandLogo asset, not Apple Face ID).
    static let unlockGlyphSize: CGFloat = 56
    /// Face-page square mark — same red medical circle as lock entry.
    static let unlockFrameSize: CGFloat = 96
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

/// Original medical lock mark — heart + static EKG, Face ID–sized.
/// Face-page static mark — heart + EKG. Not Apple Face ID scan rings.
/// One-shot squash-settle; not Apple Face ID scan rings, not `BrandLogo`.
struct LockMedGlyph: View {
    var size: CGFloat = RedMedChrome.unlockGlyphSize
    @State private var popped = false
    @State private var spark: CGFloat = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.882, green: 0.114, blue: 0.180))
            LockMedHeart()
                .fill(Color.white)
                .padding(size * 0.18)
            LockMedECG()
                .stroke(
                    Color(red: 0.949, green: 0.227, blue: 0.275),
                    style: StrokeStyle(
                        lineWidth: max(2, size * 0.045),
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .padding(size * 0.18)
            LockMedPlus()
                .stroke(Color.white.opacity(0.95), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
                .frame(width: size * 0.20, height: size * 0.20)
                .offset(x: size * 0.36, y: -size * 0.36)
                .scaleEffect(spark)
                .opacity(spark > 0.05 ? 1 : 0)
        }
        .frame(width: size, height: size)
        .compositingGroup()
        .scaleEffect(popped ? 1 : 0.76)
        .opacity(popped ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.40, dampingFraction: 0.70)) {
                popped = true
            }
            withAnimation(.easeOut(duration: 0.28).delay(0.20)) {
                spark = 1
            }
            withAnimation(.easeIn(duration: 0.22).delay(0.52)) {
                spark = 0
            }
        }
    }
}

/// Brand heart in 32×30 design space (SwiftUI y-down).
private struct LockMedHeart: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 32
        let sy = rect.height / 30
        func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + x * sx, y: rect.minY + y * sy)
        }
        var p = Path()
        p.move(to: pt(24, 0))
        p.addCurve(to: pt(16, 7), control1: pt(19.6, 0), control2: pt(17, 3.4))
        p.addCurve(to: pt(8, 0), control1: pt(15, 3.4), control2: pt(12.4, 0))
        p.addCurve(to: pt(0, 9), control1: pt(3.2, 0), control2: pt(0, 4))
        p.addCurve(to: pt(16, 28), control1: pt(0, 19), control2: pt(7, 26))
        p.addCurve(to: pt(32, 9), control1: pt(25, 26), control2: pt(32, 19))
        p.addCurve(to: pt(24, 0), control1: pt(32, 4), control2: pt(28.8, 0))
        p.closeSubpath()
        return p
    }
}

/// Static EKG polyline in the same 32×30 heart space — no pulse bump.
private struct LockMedECG: Shape {
    func path(in rect: CGRect) -> Path {
        let sx = rect.width / 32
        let sy = rect.height / 30
        let pts: [(CGFloat, CGFloat)] = [
            (7, 14), (12.15, 14), (14.3, 11), (16.8, 18), (18.97, 14), (25, 14)
        ]
        var p = Path()
        for (i, xy) in pts.enumerated() {
            let pt = CGPoint(x: rect.minX + xy.0 * sx, y: rect.minY + xy.1 * sy)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        return p
    }
}

/// Tiny medical-plus sparkle — original pickup cue, not Face ID rings.
private struct LockMedPlus: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.midX
        let cy = rect.midY
        let arm = min(rect.width, rect.height) * 0.42
        var p = Path()
        p.move(to: CGPoint(x: cx, y: cy - arm))
        p.addLine(to: CGPoint(x: cx, y: cy + arm))
        p.move(to: CGPoint(x: cx - arm, y: cy))
        p.addLine(to: CGPoint(x: cx + arm, y: cy))
        return p
    }
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

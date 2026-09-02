import SwiftUI
import UIKit

/// Shared springs / fades for owner + scanner chrome. Keep short — presence, not noise.
enum RedMedMotion {
    /// Seizure Start/Stop chrome, CPR beat. Presses are instant (`RedMedPressStyle`).
    static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.82)
}

/// Press scale for CTAs and chrome — reactive without fighting scroll.
/// Default is instant: the 0.32s CTA spring made tab hops and in-app taps feel late.
struct RedMedPressStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    var haptic: (() -> Void)? = { RedMedHaptics.light() }
    var animates: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(animates ? RedMedMotion.snappy : nil, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { haptic?() }
            }
    }
}

extension Color {
    static let redmedAccent   = Color(red: 0.882, green: 0.114, blue: 0.282) // #e11d48
    /// CTA gradient lift — pairs with `redmedAccent`, never a raw hex at call sites.
    static let redmedAccentLift = Color(red: 1.000, green: 0.447, blue: 0.537) // #ff7289
    static let redmedBg       = Color(red: 1.000, green: 0.969, blue: 0.969) // #fff7f7
    /// Heading / primary ink — same on owner chrome + passerby `--dark` / legal `--text`.
    static let redmedDark     = Color(red: 0.110, green: 0.098, blue: 0.086) // #1c1917
    static let redmedMuted    = Color(red: 0.471, green: 0.443, blue: 0.424) // #78716c
    /// Cream-lift panel fill — not pure white (white boxes on `redmedBg`).
    static let redmedSurface  = Color(red: 1.000, green: 0.953, blue: 0.957) // #fff3f4
    /// Row / chip hairline — same 8% ink as passerby dividers / legal `--border`.
    static let redmedDivider  = Color.redmedDark.opacity(0.08)
    /// Soft top wash — pairs with passerby body gradient.
    static let redmedWash     = Color(red: 1.000, green: 0.910, blue: 0.922) // #ffe8eb
}

/// Cream page with rose wash only (fill color — no BrandLogo).
/// Pages and passerby tapper share cream fill.
struct RedMedPageBackground: View {
    var body: some View {
        Color.redmedBg
            .overlay(alignment: .top) {
                RadialGradient(
                    colors: [Color.redmedWash.opacity(0.85), Color.redmedBg.opacity(0)],
                    center: .top,
                    startRadius: 20,
                    endRadius: 420
                )
                .frame(height: 520)
                .allowsHitTesting(false)
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
    var systemImage: String? = nil
    var busy: Bool = false
    var disabled: Bool = false
    var flatten: Bool = true
    let action: () -> Void

    var body: some View {
        Button {
            RedMedHaptics.medium()
            action()
        } label: {
            primaryLabel
        }
        .buttonStyle(RedMedPressStyle(haptic: nil))
        .disabled(disabled || busy)
        .opacity(busy ? 0.72 : (disabled ? RedMedChrome.disabledOpacity : 1))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var primaryLabel: some View {
        let core = HStack(spacing: 8) {
            if busy {
                ProgressView().tint(.white)
            } else if let systemImage {
                Image(systemName: systemImage)
            }
            Text(title)
        }
        .font(.system(size: 16, weight: .bold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(
            LinearGradient(
                colors: [.redmedAccentLift, .redmedAccent],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius, style: .continuous))
        .shadow(color: disabled ? .clear : RedMedChrome.accentShadow, radius: 10, y: 5)
        if busy || !flatten {
            core
        } else {
            core.drawingGroup()
        }
    }
}

/// Cream fill, accent stroke — Health import, NFC Preview.
struct OutlineButton: View {
    let title: String
    var systemImage: String? = nil
    var busy: Bool = false
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            RedMedHaptics.medium()
            action()
        } label: {
            HStack(spacing: 8) {
                if busy {
                    ProgressView().tint(.redmedAccent)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.redmedAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.redmedBg)
            .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RedMedChrome.boxRadius, style: .continuous)
                    .strokeBorder(Color.redmedAccent.opacity(0.45), lineWidth: 1.5)
            )
        }
        .buttonStyle(RedMedPressStyle(haptic: nil))
        .disabled(disabled || busy)
        .opacity(busy ? 0.72 : (disabled ? RedMedChrome.disabledOpacity : 1))
        .accessibilityAddTraits(.isButton)
    }
}

/// Compact dark/accent fill — Copy coordinates, SOS.
struct CompactFillButton: View {
    let title: String
    var systemImage: String? = nil
    var fill: Color = .redmedDark
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius, style: .continuous))
        }
        .buttonStyle(RedMedPressStyle(haptic: nil))
        .disabled(disabled)
        .opacity(disabled ? RedMedChrome.disabledOpacity : 1)
        .accessibilityAddTraits(.isButton)
    }
}

/// Trailing chrome text — owner **Edit** (own row, not on the YOU-card header), NFC Preview **Back**, scanner **Back**, Aid topic **Back**.
/// Help on 911 / Aid / NFC / Edit stays chrome text, not a bottom dock.
/// No Help on the owner RedMed tab itself.
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
        // Same cream + rose wash as owner RedMed — not a flat cream band.
        .redmedTopChromeWash()
    }
}

/// Edit modal bar: Cancel (left), Save (right).
/// Same type size and bar height as the owner Help modal's Done bar.
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
        .redmedTopChromeWash()
    }
}

extension OwnerModalActionBar where Center == EmptyView {
    /// Cancel / Save only — no center Help button.
    init(
        leadingTitle: String,
        leadingWeight: Font.Weight = .regular,
        leadingAction: @escaping () -> Void,
        trailingTitle: String,
        trailingWeight: Font.Weight = .bold,
        trailingAction: @escaping () -> Void
    ) {
        self.init(
            leadingTitle: leadingTitle,
            leadingWeight: leadingWeight,
            leadingAction: leadingAction,
            trailingTitle: trailingTitle,
            trailingWeight: trailingWeight,
            trailingAction: trailingAction,
            center: { EmptyView() }
        )
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
    /// Cancel / Save / Done inside owner Help · Edit modals.
    static let modalActionSize: CGFloat = 17
    static let modalBarHeight: CGFloat = 52
    static let modalSideMinWidth: CGFloat = 64
    static let boxRadius: CGFloat = 12
    static let chipRadius: CGFloat = 8
    /// Tapper / empty YOU-card BrandLogo diameter (`--logo` matches).
    static let logoSize: CGFloat = 72
    /// BrandWordmark lockup on topic pages (NFC / Aid / 911 are content-first — Help chrome only).
    static let wordmarkHeight: CGFloat = 42
    static let pagePadX: CGFloat = 16
    static let wordmarkTop: CGFloat = 6
    static let wordmarkBottom: CGFloat = 4
    static let rowFont: CGFloat = 15
    static let rowVPad: CGFloat = 13
    static let tabBarHeight: CGFloat = 56.5
    static let tabTopRadius: CGFloat = 18
    static let disabledOpacity: Double = 0.48
    static let cardShadow = Color.black.opacity(0.045)
    static let accentShadow = Color.redmedAccent.opacity(0.18)
}

/// Pinned BrandWordmark row — topic pages (not Aid, 911, or NFC).
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
        // Local cream + wash (no ignoresSafeArea) — NFC Help chrome sits above this.
        .background {
            ZStack {
                Color.redmedBg
                RadialGradient(
                    colors: [Color.redmedWash.opacity(0.85), Color.redmedBg.opacity(0)],
                    center: .top,
                    startRadius: 20,
                    endRadius: 420
                )
            }
        }
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
    ///
    /// `flatten` groups fill+shadow so scrolling doesn't recompute the soft
    /// shadow on every frame. Uses `compositingGroup` (layer) not
    /// `drawingGroup` (offscreen Metal bitmap) so tall cards share GPU with
    /// the tapper WKWebView instead of allocating a second huge texture.
    /// Small chrome (tab bar, CTAs, CPR beat) still uses `drawingGroup`.
    /// Pass `false` for live-editing content (focused `TextField`).
    func redmedBox(elevated: Bool = true, flatten: Bool = true) -> some View {
        let card = self
            .background(Color.redmedSurface)
            .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius, style: .continuous))
            .shadow(color: elevated ? RedMedChrome.cardShadow : .clear, radius: 8, y: 3)
        return Group {
            if flatten {
                card.compositingGroup()
            } else {
                card
            }
        }
    }

    /// Opaque cream behind top Help / Edit / Back chrome.
    /// Extends into the top safe area so system white never cuts off above the page.
    func redmedTopChromeFill() -> some View {
        self.background(alignment: .top) {
            Color.redmedBg
                .ignoresSafeArea(edges: .top)
        }
    }

    /// Same opaque cream + rose radial wash as `RedMedPageBackground` / passerby
    /// `tapper.html` body. Owner chrome (RedMed, 911, Aid, NFC, Help, Edit,
    /// Preview, topic sheets) uses this so headers match the YOU-card page.
    func redmedTopChromeWash() -> some View {
        self.background(alignment: .top) {
            ZStack {
                Color.redmedBg
                RadialGradient(
                    colors: [Color.redmedWash.opacity(0.85), Color.redmedBg.opacity(0)],
                    center: .top,
                    startRadius: 20,
                    endRadius: 420
                )
            }
            .ignoresSafeArea(edges: .top)
        }
    }
}

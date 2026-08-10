import SwiftUI
import UIKit

// MARK: - Layout (393×852 baseline — iPhone 15/16 class)

/// Scales spacing and control sizes from a 393×852 pt design baseline.
/// Read via `@Environment(\.layoutMetrics)` — never hardcode point values in views.
///
/// **Viewport, not pixel density.** `@2x`/`@3x` only affects asset sharpness.
/// Layout keys off the **scrollable area** each tab gets: screen bounds minus
/// safe-area insets and tab bar. That keeps SE, standard, and Pro Max proportional
/// without per-device branches in views.
///
/// **Safe areas beat resolution.** Let SwiftUI apply status bar / home-indicator
/// insets — constants below are design-review references only.
struct LayoutMetrics: Equatable {
    static let baselineWidth: CGFloat = 393
    static let baselineHeight: CGFloat = 852

    /// Figma / mockup — standard iPhone 15/16 class (matches code baseline).
    static let mockupFrameStandard = CGSize(width: 393, height: 852)
    /// Figma / mockup — large Pro Max class; spot-check only, no second code path.
    static let mockupFrameLarge = CGSize(width: 440, height: 956)

    /// Figma / design-review only — runtime uses `GeometryReader.safeAreaInsets`.
    static let referenceDynamicIslandTopInset: CGFloat = 59
    /// Figma / design-review only — tab bar adds its own height on top of this.
    static let referenceHomeIndicatorInset: CGFloat = 34
    /// Standard tab bar chrome (stacked items).
    static let tabBarHeight: CGFloat = 49

    /// Baseline scroll viewport on the 393×852 design frame.
    static var baselineViewportHeight: CGFloat {
        baselineHeight - referenceDynamicIslandTopInset - referenceHomeIndicatorInset - tabBarHeight
    }

    /// Scale floor — keeps SE-class hero titles readable (~20 pt bold).
    static let scaleMin: CGFloat = 0.62
    /// Scale ceiling — Pro Max doesn't balloon past the design baseline.
    static let scaleMax: CGFloat = 0.83

    let size: CGSize
    let safeAreaInsets: EdgeInsets

    init(size: CGSize, safeAreaInsets: EdgeInsets = EdgeInsets()) {
        self.size = size
        self.safeAreaInsets = safeAreaInsets
    }

    static let baseline = LayoutMetrics(
        size: CGSize(width: baselineWidth, height: baselineHeight)
    )

    /// Width available to tab content (full bounds — horizontal pad is `screenPad`).
    var viewportWidth: CGFloat { size.width }

    /// Height available below status bar / above tab bar — what scroll views actually get.
    var viewportHeight: CGFloat {
        max(
            480,
            size.height - safeAreaInsets.top - safeAreaInsets.bottom - Self.tabBarHeight
        )
    }

    private var widthRatio: CGFloat {
        viewportWidth / Self.baselineWidth
    }

    private var heightRatio: CGFloat {
        viewportHeight / Self.baselineViewportHeight
    }

    /// Primary scale for fonts, icons, and horizontal rhythm.
    /// Height-weighted — scroll content is vertically constrained more often.
    var scale: CGFloat {
        let blended = widthRatio * 0.38 + heightRatio * 0.62
        return min(max(blended, Self.scaleMin), Self.scaleMax)
    }

    /// Extra vertical compression on shorter viewports (SE, mini).
    private var verticalFactor: CGFloat {
        switch viewportHeight {
        case ..<620: return 0.82
        case ..<680: return 0.88
        case ..<740: return 0.93
        default: return 1.0
        }
    }

    /// General scaled points (fonts, widths, radii).
    func s(_ points: CGFloat) -> CGFloat { points * scale }

    /// Vertical spacing — height-tier tightening on top of scale.
    func sv(_ points: CGFloat) -> CGFloat { points * scale * verticalFactor }

    /// Scaled semantic fonts — use instead of raw `.subheadline` / `.caption` in tab screens.
    func bodyFont(weight: Font.Weight = .regular) -> Font {
        .system(size: s(15), weight: weight)
    }

    func subheadlineFont(weight: Font.Weight = .regular) -> Font {
        .system(size: s(14), weight: weight)
    }

    func footnoteFont(weight: Font.Weight = .regular) -> Font {
        .system(size: s(13), weight: weight)
    }

    func captionFont(weight: Font.Weight = .regular) -> Font {
        .system(size: s(12), weight: weight)
    }

    func caption2Font(weight: Font.Weight = .regular) -> Font {
        .system(size: s(11), weight: weight)
    }

    func title3Font(weight: Font.Weight = .bold) -> Font {
        .system(size: s(19), weight: weight)
    }

    var screenPad: CGFloat { s(16) }
    /// Top inset for each tab's page header — pulls content up slightly under the nav bar.
    var pageTopInset: CGFloat { sv(2) }
    var spaceXS: CGFloat { sv(4) }
    var spaceSM: CGFloat { sv(7) }
    var spaceMD: CGFloat { sv(10) }
    var spaceLG: CGFloat { sv(14) }
    var spaceXL: CGFloat { sv(18) }
    var space2XL: CGFloat { sv(20) }
    /// Extra scroll breathing room *below* content — not a substitute for the 34 pt home indicator.
    var screenBottom: CGFloat { sv(16) }
    var screenBottomLarge: CGFloat { sv(22) }
    /// Matched height for side-by-side Call 911 + Scan on Find 911.
    var emergencyPairButtonHeight: CGFloat { sv(54) }
    /// Vertical padding inside elevated cards (GPS, status chips).
    var cardPadV: CGFloat { sv(18) }

    var cardRadius: CGFloat { s(22) }
    var chipRadius: CGFloat { s(14) }
    var innerRadius: CGFloat { s(12) }
    var iconWellRadius: CGFloat { s(12) }

    var iconWell: CGFloat { s(40) }
    var iconWellLarge: CGFloat { s(48) }
    var aidPaneMinHeight: CGFloat { sv(100) }
    var cprPulse: CGFloat { s(52) }
    private var compactHeight: Bool { viewportHeight < 680 }
    var nfcHeroInner: CGFloat { s(compactHeight ? 92 : 104) }
    var nfcHeroOuter: CGFloat { s(compactHeight ? 112 : 128) }
    var stepBadge: CGFloat { s(24) }
    var bulletDot: CGFloat { s(5) }
    var statusDot: CGFloat { s(6) }
    var topicIcon: CGFloat { s(20) }
    var cprResetMaxWidth: CGFloat { s(76) }

    func heroTitleFont() -> Font {
        .system(size: s(25), weight: .bold, design: .rounded)
    }

    func emergencyNameFont() -> Font {
        .system(size: s(30), weight: .bold, design: .rounded)
    }

    func navTitleFont() -> Font {
        .system(size: s(17), weight: .bold, design: .rounded)
    }

    func nfcGlyphFont() -> Font {
        .system(size: s(50), weight: .medium)
    }

    func brandWordmarkHeight(_ size: BrandMark.Size) -> CGFloat {
        switch size {
        case .hero: return s(42)
        case .nav: return s(34)
        case .compact: return s(28)
        }
    }

    func brandCoverFrame(_ size: BrandMark.Size) -> CGFloat {
        switch size {
        case .hero: return s(48)
        case .nav: return s(40)
        case .compact: return s(32)
        }
    }
}

private struct LayoutMetricsKey: EnvironmentKey {
    static let defaultValue = LayoutMetrics.baseline
}

extension EnvironmentValues {
    var layoutMetrics: LayoutMetrics {
        get { self[LayoutMetricsKey.self] }
        set { self[LayoutMetricsKey.self] = newValue }
    }
}

private struct LayoutMetricsScope: ViewModifier {
    func body(content: Content) -> some View {
        GeometryReader { geo in
            content
                .frame(width: geo.size.width, height: geo.size.height)
                .environment(
                    \.layoutMetrics,
                    LayoutMetrics(size: geo.size, safeAreaInsets: geo.safeAreaInsets)
                )
        }
    }
}

// MARK: - Colors

/// RedMed tokens — medical rose, Gemini-like soft motion, dead-simple chrome.
enum AppTheme {
    static let accent = Color(red: 0.882, green: 0.114, blue: 0.282) // #e11d48
    static let accentSoft = Color(red: 0.882, green: 0.114, blue: 0.282).opacity(0.10)
    /// Gradient highlight paired above `accent` (top stop of primary-button / hero gradients).
    static let accentLight = Color(red: 1, green: 0.45, blue: 0.55)
    static let medical = accent
    static let medicalSoft = accentSoft
    static let teal = Color(red: 0.624, green: 0.071, blue: 0.224) // #9f1239 deep rose
    static let tealSoft = Color(red: 0.624, green: 0.071, blue: 0.224).opacity(0.08)
    static let ink = Color(red: 0.110, green: 0.098, blue: 0.090) // #1c1917
    static let muted = Color(red: 0.471, green: 0.443, blue: 0.424) // #78716c
    static let ok = accent
    static let pageBg = Color(red: 1.0, green: 0.969, blue: 0.969) // #fff7f7
    static let cardBg = Color.white.opacity(0.92)
    static let line = Color(red: 0.110, green: 0.098, blue: 0.090).opacity(0.08)
}

// MARK: - Brand

struct BrandMark: View {
    enum Size { case hero, nav, compact }

    @Environment(\.layoutMetrics) private var layout

    var size: Size = .nav
    var showTagline: Bool = false
    var titleOverride: String?

    var body: some View {
        let cover = layout.brandCoverFrame(size)
        VStack(alignment: .leading, spacing: size == .hero ? layout.spaceSM : layout.spaceXS) {
            if let titleOverride, !titleOverride.isEmpty {
                HStack(spacing: layout.s(10)) {
                    Image("BrandLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: cover, height: cover)
                        .clipShape(RoundedRectangle(cornerRadius: cover * 0.28, style: .continuous))
                        .shadow(color: AppTheme.accent.opacity(0.12), radius: layout.s(6), y: layout.s(3))

                    VStack(alignment: .leading, spacing: layout.s(2)) {
                        Text(titleOverride)
                            .font(size == .hero ? layout.heroTitleFont() : layout.navTitleFont())
                            .foregroundStyle(AppTheme.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                        Text("Linked bracelet")
                            .font(.caption2.weight(.bold))
                            .tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(AppTheme.accent.opacity(0.85))
                    }
                }
            } else {
                Image("BrandWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: layout.brandWordmarkHeight(size))
                    .accessibilityLabel("RedMed")
            }

            if showTagline {
                VStack(alignment: .leading, spacing: layout.s(4)) {
                    Text(DesignPagePlacement.brandTagline)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.accent)
                    Text(DesignPagePlacement.brandLead)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct ScreenAtmosphere: View {
    @Environment(\.layoutMetrics) private var layout

    var body: some View {
        ZStack {
            AppTheme.pageBg
            RadialGradient(
                colors: [AppTheme.accent.opacity(0.05), Color.clear],
                center: .topLeading,
                startRadius: layout.s(20),
                endRadius: layout.s(280)
            )
            RadialGradient(
                colors: [Color(red: 1.0, green: 0.45, blue: 0.55).opacity(0.04), Color.clear],
                center: .bottomTrailing,
                startRadius: layout.s(40),
                endRadius: layout.s(320)
            )
        }
        .ignoresSafeArea()
    }
}

struct SectionEyebrow: View {
    @Environment(\.layoutMetrics) private var layout

    let text: String
    var tint: Color = AppTheme.accent

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(tint)
            .padding(.horizontal, layout.s(10))
            .padding(.vertical, layout.s(5))
            .background(tint.opacity(0.1))
            .clipShape(Capsule())
    }
}

enum CopyHighlight {
    private static let phrases = [
        "Call 911", "call 911", "911 now", "911 first", "Press hard",
        "Don't stop", "Do NOT", "Note the time", "life-threatening",
        "Not breathing", "Can't breathe", "Keep warm", "Cool fast",
        "shivering stops", "hot dry skin"
    ]

    static func attributed(_ text: String, base: Color = AppTheme.ink) -> AttributedString {
        var result = AttributedString(text)
        result.foregroundColor = base
        result.font = .subheadline.weight(.medium)
        for phrase in phrases.sorted(by: { $0.count > $1.count }) {
            var search = result.startIndex
            while search < result.endIndex,
                  let range = result[search...].range(of: phrase, options: .caseInsensitive) {
                result[range].backgroundColor = AppTheme.accent.opacity(0.14)
                result[range].foregroundColor = AppTheme.teal
                result[range].font = .subheadline.weight(.bold)
                search = range.upperBound
            }
        }
        return result
    }
}

struct IconWell: View {
    @Environment(\.layoutMetrics) private var layout

    let systemName: String
    var tint: Color = AppTheme.accent
    var soft: Color = AppTheme.accentSoft
    var size: CGFloat?

    private var resolvedSize: CGFloat { size ?? layout.iconWell }

    var body: some View {
        let side = resolvedSize
        ZStack {
            RoundedRectangle(cornerRadius: layout.iconWellRadius, style: .continuous)
                .fill(soft)
            Image(systemName: systemName)
                .font(.system(size: side * 0.38, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: side, height: side)
    }
}

struct SoftStatusChip: View {
    @Environment(\.layoutMetrics) private var layout

    let text: String
    var warning: Bool = false

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(warning ? AppTheme.accent : AppTheme.muted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, layout.s(14))
            .padding(.vertical, layout.spaceMD)
            .frame(maxWidth: .infinity)
            .background(warning ? AppTheme.accentSoft : Color.white.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: layout.chipRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: layout.chipRadius, style: .continuous)
                    .stroke(warning ? AppTheme.accent.opacity(0.2) : AppTheme.line, lineWidth: 1)
            )
    }
}

/// Owner guidance — band must be re-written after profile edits; passersby read the chip.
/// Shared NFC programming hero — Write Tag tab and bracelet setup sheet.
struct NFCHeroHeader: View {
    @Environment(\.layoutMetrics) private var layout

    var title: String
    var subtitle: String

    var body: some View {
        VStack(spacing: layout.spaceLG) {
            ZStack {
                Circle()
                    .fill(AppTheme.medicalSoft)
                    .frame(width: layout.nfcHeroInner, height: layout.nfcHeroInner)
                Circle()
                    .stroke(AppTheme.medical.opacity(0.2), lineWidth: 1.5)
                    .frame(width: layout.nfcHeroOuter, height: layout.nfcHeroOuter)
                Image(systemName: "wave.3.right.circle.fill")
                    .font(layout.nfcGlyphFont())
                    .foregroundStyle(AppTheme.medical)
                    .symbolRenderingMode(.hierarchical)
            }
            .padding(.top, layout.spaceMD)

            VStack(spacing: layout.spaceSM) {
                Text(title)
                    .font(layout.heroTitleFont())
                    .tracking(-0.4)
                    .foregroundStyle(AppTheme.ink)
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Post-write check — native emergency card matches what passersby see in Safari.
struct BraceletVerifySection: View {
    @Environment(\.layoutMetrics) private var layout

    var scanTitle: String = "Scan your bracelet"

    var body: some View {
        VStack(alignment: .leading, spacing: layout.spaceMD) {
            SectionEyebrow(text: "Verify", tint: AppTheme.muted)
            Text("After writing, scan your band here to see the same emergency card a stranger gets.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            ScanEmergencyCardControl(title: scanTitle)
        }
        .padding(layout.spaceLG)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appCard(elevated: false)
    }
}

struct BraceletSyncInstructions: View {
    @Environment(\.layoutMetrics) private var layout

    var body: some View {
        VStack(alignment: .leading, spacing: layout.s(10)) {
            Text("Keep your band in sync")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            instructionRow(
                "Link your bracelet once (My ID → bracelet icon → write/read)."
            )
            instructionRow(
                "Save after every edit and hold your phone to the band when prompted."
            )
            instructionRow(
                "If you cancel the NFC prompt, this app has the new data but the band — and what passersby see in Safari — stays stale until you save again or use NFC tab → Write."
            )
        }
        .padding(layout.s(14))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: layout.chipRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: layout.chipRadius, style: .continuous)
                .stroke(AppTheme.line, lineWidth: 1)
        )
    }

    private func instructionRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: layout.s(8)) {
            Text("•")
                .font(.footnote.weight(.bold))
                .foregroundStyle(AppTheme.accent)
                .padding(.top, 1)
            Text(text)
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.layoutMetrics) private var layout

    var enabled: Bool = true
    var prominent: Bool = false
    var fixedHeight: CGFloat? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(prominent ? layout.title3Font() : .headline.weight(.bold))
            .lineLimit(fixedHeight == nil ? nil : 1)
            .minimumScaleFactor(fixedHeight == nil ? 1 : 0.85)
            .frame(maxWidth: .infinity)
            .frame(height: fixedHeight)
            .padding(.vertical, fixedHeight == nil ? (prominent ? layout.sv(17) : layout.spaceLG) : 0)
            .background(
                LinearGradient(
                    colors: enabled
                        ? [Color(red: 0.984, green: 0.443, blue: 0.522), AppTheme.accent]
                        : [Color.gray.opacity(0.55), Color.gray.opacity(0.45)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .overlay {
                if prominent, enabled {
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.34), AppTheme.teal.opacity(0.18)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 0.5
                        )
                }
            }
            .shadow(
                color: enabled
                    ? AppTheme.accent.opacity(prominent ? 0.08 : 0.18)
                    : .clear,
                radius: prominent ? layout.s(4) : layout.s(10),
                y: prominent ? layout.s(2) : layout.s(4)
            )
            .opacity(configuration.isPressed ? 0.92 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.layoutMetrics) private var layout

    var fixedHeight: CGFloat? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .lineLimit(fixedHeight == nil ? nil : 2)
            .minimumScaleFactor(fixedHeight == nil ? 1 : 0.85)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(height: fixedHeight)
            .padding(.vertical, fixedHeight == nil ? layout.sv(14) : 0)
            .background(Color.white.opacity(0.82))
            .foregroundStyle(AppTheme.ink)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(AppTheme.line, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: layout.s(8), y: layout.s(3))
            .shadow(color: Color.black.opacity(0.03), radius: layout.s(6), y: layout.s(2))
            .opacity(configuration.isPressed ? 0.88 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

struct InkButtonStyle: ButtonStyle {
    @Environment(\.layoutMetrics) private var layout

    var fixedHeight: CGFloat? = nil

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.bold))
            .lineLimit(fixedHeight == nil ? nil : 2)
            .minimumScaleFactor(fixedHeight == nil ? 1 : 0.85)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .frame(height: fixedHeight)
            .padding(.vertical, fixedHeight == nil ? layout.sv(16) : 0)
            .padding(.horizontal, fixedHeight == nil ? layout.spaceLG : layout.spaceSM)
            .background(AppTheme.ink.opacity(configuration.isPressed ? 0.88 : 1))
            .foregroundStyle(.white)
            .clipShape(Capsule())
            .shadow(color: Color.black.opacity(0.12), radius: layout.s(10), y: layout.s(4))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

/// In-app 911 dial — `Button` + `telprompt:` (Link + ButtonStyle does not reliably open Phone).
struct Call911Button: View {
    @Environment(\.layoutMetrics) private var layout

    var title: String = "Call 911"
    var prominent: Bool = true
    var secondary: Bool = false
    /// Side-by-side with Scan — matched capsule height, top-aligned pair.
    var pairLayout: Bool = false

    var body: some View {
        Group {
            if secondary {
                Button(action: dial) {
                    Text(title)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(SecondaryButtonStyle(
                    fixedHeight: pairLayout ? layout.emergencyPairButtonHeight : nil
                ))
            } else {
                Button(action: dial) {
                    Text(title)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(PrimaryButtonStyle(
                    prominent: pairLayout ? false : prominent,
                    fixedHeight: pairLayout ? layout.emergencyPairButtonHeight : nil
                ))
            }
        }
    }

    private func dial() {
        guard let url = EmergencySummaryBuilder.call911URL else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Cards

struct CardModifier: ViewModifier {
    @Environment(\.layoutMetrics) private var layout

    var elevated: Bool = true

    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBg)
            .clipShape(RoundedRectangle(cornerRadius: layout.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: layout.cardRadius, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            )
            .shadow(
                color: AppTheme.accent.opacity(elevated ? 0.04 : 0),
                radius: elevated ? layout.s(8) : 0,
                y: elevated ? layout.s(3) : 0
            )
    }
}

extension View {
    func appCard(elevated: Bool = true) -> some View {
        modifier(CardModifier(elevated: elevated))
    }

    func screenAtmosphere() -> some View {
        background { ScreenAtmosphere() }
    }

    /// Installs scaled layout metrics from the current container (393×852 baseline).
    func withLayoutMetrics() -> some View {
        modifier(LayoutMetricsScope())
    }
}

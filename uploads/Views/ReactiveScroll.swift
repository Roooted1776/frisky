import SwiftUI

/// Preference keys for scroll offset + content size so progress is
/// `offset / max(content − viewport, 1)` — proportionate to page height.
private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Thin top progress rail driven by scroll progress (page-height normalized).
struct ReactiveScrollChrome: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var progress: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var contentHeight: CGFloat = 0
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: "redmedScroll")
            .background {
                GeometryReader { geo in
                    Color.clear
                        .preference(key: ViewportHeightKey.self, value: geo.size.height)
                }
            }
            .onPreferenceChange(ViewportHeightKey.self) { viewportHeight = $0; updateProgress() }
            .onPreferenceChange(ScrollOffsetKey.self) { offset = $0; updateProgress() }
            .onPreferenceChange(ScrollContentHeightKey.self) { contentHeight = $0; updateProgress() }
            .overlay(alignment: .top) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.black.opacity(0.05))
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.accent, AppTheme.accent.opacity(0.85)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, geo.size.width * progress))
                    }
                }
                .frame(height: 3)
                .allowsHitTesting(false)
                .opacity(progress > 0.01 ? 1 : 0.35)
                .accessibilityHidden(true)
            }
            .environment(\.scrollProgress, progress)
            .environment(\.scrollParallax, reduceMotion ? 0 : progress)
    }

    private func updateProgress() {
        let maxScroll = max(contentHeight - viewportHeight, 1)
        let next = min(1, max(0, offset / maxScroll))
        if abs(next - progress) > 0.002 {
            progress = next
        }
    }
}

private struct ViewportHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ScrollProgressKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

private struct ScrollParallaxKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var scrollProgress: CGFloat {
        get { self[ScrollProgressKey.self] }
        set { self[ScrollProgressKey.self] = newValue }
    }

    var scrollParallax: CGFloat {
        get { self[ScrollParallaxKey.self] }
        set { self[ScrollParallaxKey.self] = newValue }
    }
}

extension View {
    /// Tracks scroll offset/height inside a ScrollView for proportionate progress.
    func reactiveScrollTrack() -> some View {
        background {
            GeometryReader { geo in
                Color.clear
                    .preference(
                        key: ScrollOffsetKey.self,
                        value: -geo.frame(in: .named("redmedScroll")).minY
                    )
                    .preference(key: ScrollContentHeightKey.self, value: geo.size.height)
            }
        }
    }

    /// Installs the top progress rail; pair with `.reactiveScrollTrack()` on scroll content.
    func reactiveScrollChrome() -> some View {
        modifier(ReactiveScrollChrome())
    }
}

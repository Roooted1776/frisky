import SwiftUI
import UIKit

/// Hides PHI from iOS app-switcher snapshots taken when the app resigns active.
/// Apply at the owner window root — scanners still need a readable emergency card
/// only while active; when backgrounded, blur everything.
struct PrivacySnapshotGuard<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            content

            if scenePhase != .active {
                privacyCover
                    .transition(.opacity)
                    .zIndex(999)
            }
        }
        .animation(.easeInOut(duration: 0.12), value: scenePhase)
    }

    private var privacyCover: some View {
        ZStack {
            Color.redmedBg.ignoresSafeArea()
            VStack(spacing: 12) {
                Image("BrandLogo")
                    .resizable()
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                Text("RedMed")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.redmedDark)
                Text("Profile hidden")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedMuted)
            }
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Blocks system autofill / keyboard learning caches for PHI fields and marks
    /// content privacy-sensitive so app-switcher snapshots do not retain glyphs.
    func vaultSafeTextInput(
        capitalization: TextInputAutocapitalization = .sentences
    ) -> some View {
        self
            .textContentType(nil as UITextContentType?)
            .autocorrectionDisabled(true)
            .textInputAutocapitalization(capitalization)
            .privacySensitive()
    }
}

import SwiftUI
import UIKit

/// Hides PHI from iOS app-switcher snapshots and active screen capture / mirroring.
/// Apply at the owner window root — scanners still need a readable emergency card
/// only while active; when backgrounded or recorded, cover everything.
struct PrivacySnapshotGuard<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var screenCaptured = UIScreen.main.isCaptured
    /// Cold launch reports `.inactive` before first `.active`. Covering then paints
    /// a blank shell over the real UI and reads as a long hang after the launch screen.
    @State private var hasBeenActive = false
    @ViewBuilder private var content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    private var mustCover: Bool {
        if screenCaptured { return true }
        // Stay uncovered until the first active frame so tabs paint immediately.
        guard hasBeenActive else { return false }
        return scenePhase != .active
    }

    var body: some View {
        ZStack {
            content()

            // No opacity animation — iOS may capture the switcher snapshot while a
            // fade is mid-flight, leaking PHI under a translucent cover.
            if mustCover {
                privacyCover
                    .zIndex(999)
            }
        }
        .onAppear {
            if scenePhase == .active {
                hasBeenActive = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                hasBeenActive = true
            } else if hasBeenActive {
                SecurePasteboard.clear()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            screenCaptured = UIScreen.main.isCaptured
            if screenCaptured {
                SecurePasteboard.clear()
            }
        }
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

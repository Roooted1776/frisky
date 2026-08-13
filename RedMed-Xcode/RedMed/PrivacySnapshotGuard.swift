import SwiftUI
import UIKit

/// Hides PHI from iOS app-switcher snapshots and active screen capture / mirroring.
/// Apply at the owner window root — scanners still need a readable emergency card
/// only while active; when backgrounded or recorded, cover everything.
///
/// FaceTime / Screen Recording sets `UIScreen.isCaptured`. Do **not** cover the
/// lock / watermark shell — RAM is purged then, and a cover blocks Face ID /
/// Unlock so the owner cannot enter. Cover only when PHI is actually in memory.
///
/// Non-capture cover is **`.background` only** (with PHI). Face ID / LAContext
/// put the scene `.inactive` — covering then blanks the UI mid-unlock and
/// painted a second BrandLogo over the watermark lock. App-switcher snapshots
/// still get a cover on true background while PHI is in RAM; after
/// `OwnerAppLock` purges, the lock shell itself has no PHI to leak.
struct PrivacySnapshotGuard<Content: View>: View {
    @EnvironmentObject private var profile: ProfileData
    @Environment(\.scenePhase) private var scenePhase
    /// Default false — read `UIScreen.isCaptured` after first paint (see onAppear).
    @State private var screenCaptured = false
    /// Cold launch reports `.inactive` before first `.active`. Covering then paints
    /// a blank shell over the real UI and reads as a long hang after the launch screen.
    @State private var hasBeenActive = false
    @ViewBuilder private var content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    private var phiInMemory: Bool {
        profile.hasSensitiveProfileData || profile.holdsEditingSession
    }

    private var mustCover: Bool {
        // Capture cover only while PHI is resident — lock / Unlock must stay tappable.
        if screenCaptured {
            return phiInMemory
        }
        // Stay uncovered until the first active frame so tabs paint immediately.
        guard hasBeenActive else { return false }
        // App-switcher / true background only — Face ID / LAContext put the scene
        // `.inactive` and would blank the UI mid-unlock (same rule as VaultHistoryView).
        guard scenePhase == .background else { return false }
        return phiInMemory
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
            screenCaptured = UIScreen.main.isCaptured
            if scenePhase == .active {
                hasBeenActive = true
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                hasBeenActive = true
            } else if phase == .background, hasBeenActive {
                // Clear on true background only — `.inactive` (Control Center /
                // app switcher peek) would wipe coords before the user can paste.
                SecurePasteboard.clear()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            let nowCaptured = UIScreen.main.isCaptured
            screenCaptured = nowCaptured
            if nowCaptured {
                SecurePasteboard.clear()
                if phiInMemory {
                    VaultHistoryStore.shared.record(.screenCaptureCovered, detail: "share")
                }
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
                    .clipShape(Circle())
                Text("RedMed")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.redmedDark)
                Text(screenCaptured ? "Hidden while screen sharing" : "Profile hidden")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.redmedMuted)
                if screenCaptured {
                    Text("Stop FaceTime screen share or Screen Recording to view your profile.")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.redmedMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
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

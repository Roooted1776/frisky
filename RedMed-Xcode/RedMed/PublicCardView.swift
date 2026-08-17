import SwiftUI

private struct ScannerSessionKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ScannerDismissKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

private struct OwnerHelpOpenKey: EnvironmentKey {
    static let defaultValue: Binding<Bool>? = nil
}

extension EnvironmentValues {
    /// True when this tree is the first-responder / scan shell (no owner edit).
    var isScannerSession: Bool {
        get { self[ScannerSessionKey.self] }
        set { self[ScannerSessionKey.self] = newValue }
    }

    /// Optional Back action when the scanner shell is presented over the owner app.
    var scannerDismiss: (() -> Void)? {
        get { self[ScannerDismissKey.self] }
        set { self[ScannerDismissKey.self] = newValue }
    }

    /// Presents `HelpMenuView` from the nearest `presentsOwnerHelp()` root.
    /// Sheets and full-screen covers need their own root or Help opens behind them.
    var ownerHelpOpen: Binding<Bool>? {
        get { self[OwnerHelpOpenKey.self] }
        set { self[OwnerHelpOpenKey.self] = newValue }
    }
}

/// Passerby / rescuer shell helpers (ped / EMS).
///
/// Real bracelet tap opens hosted **HTML** `tapper.html#d=…` (no app, **no
/// Face ID / biometrics / login / passcode** — tap-to-view is ungated). Owner
/// NFC Preview / NFC Scan use `PasserbyHTMLCardView` — same bundled `tapper.html` with
/// `?src=app` so SOS does not auto-arm. This file keeps `isScannerSession` /
/// Back chrome for any remaining native scanner embedding.
struct PublicCardView: View {
    @StateObject private var snapshot: ProfileData
    @Environment(\.dismiss) private var dismiss

    init(profile: ProfileData) {
        _snapshot = StateObject(wrappedValue: profile.snapshot())
    }

    var body: some View {
        ContentView()
            .environmentObject(snapshot)
            .environment(\.isScannerSession, true)
            .environment(\.scannerDismiss, { dismiss() })
    }
}

/// Dismisses the Preview scanner / ped shell. Shown on RedMed, 911, and Aid.
/// Same `ChromeTextAction` as owner Help/Edit — accent red text, no chip box.
struct ScannerBackButton: View {
    @Environment(\.scannerDismiss) private var scannerDismiss

    var body: some View {
        if let scannerDismiss {
            ChromeTextAction(title: "Back", action: scannerDismiss)
        }
    }
}

/// Opens Help from any native chrome that opted into `presentsOwnerHelp()`.
/// Hidden when that modifier is missing (lock shell, previews).
struct OwnerHelpButton: View {
    @Environment(\.ownerHelpOpen) private var ownerHelpOpen

    var body: some View {
        if let ownerHelpOpen {
            ChromeTextAction(title: "Help") {
                ownerHelpOpen.wrappedValue = true
            }
            .accessibilityIdentifier("owner-help")
        }
    }
}

/// Sibling Help row (same metrics as RedMed). Used on 911 / Aid / NFC so
/// page sections sit below Help instead of under an overlay. RedMed owns its own bar.
struct PageHelpChrome<Trailing: View>: View {
    @Environment(\.isScannerSession) private var isScannerSession
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if isScannerSession {
                ScannerBackButton()
                Spacer(minLength: 0)
                OwnerHelpButton()
            } else {
                OwnerHelpButton()
                Spacer(minLength: 0)
                trailing()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .center)
        .padding(.horizontal, RedMedChrome.pagePadX)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

extension PageHelpChrome where Trailing == EmptyView {
    init() {
        self.trailing = { EmptyView() }
    }
}

/// Local Help cover so the button works on tab roots and on sheets / full-screen covers.
private struct PresentsOwnerHelp: ViewModifier {
    @State private var showHelp = false
    @Environment(\.isScannerSession) private var isScannerSession
    @EnvironmentObject private var profile: ProfileData

    func body(content: Content) -> some View {
        content
            .environment(\.ownerHelpOpen, $showHelp)
            .fullScreenCover(isPresented: $showHelp) {
                HelpMenuView(
                    onOpenNFC: isScannerSession ? nil : {
                        showHelp = false
                        NotificationCenter.default.post(name: .redMedOpenNFCTab, object: nil)
                    }
                )
                .environmentObject(profile)
                .environment(\.isScannerSession, isScannerSession)
                .presentationBackground(Color.redmedBg)
            }
    }
}

extension View {
    /// Help button target for this presentation root. Apply again on sheets and covers.
    func presentsOwnerHelp() -> some View {
        modifier(PresentsOwnerHelp())
    }
}

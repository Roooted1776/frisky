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
    /// Used on the tap / Preview card so policies stay one tap away.
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
/// Same `ChromeTextAction` as owner Edit — accent red text, no chip box.
struct ScannerBackButton: View {
    @Environment(\.scannerDismiss) private var scannerDismiss

    var body: some View {
        if let scannerDismiss {
            ChromeTextAction(title: "Back", action: scannerDismiss)
        }
    }
}

/// Opens Help from chrome that opted into `presentsOwnerHelp()`.
/// Owner tabs do not show this. The tap / Preview card does.
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

/// Sibling top chrome. Scanner sessions keep Back so Preview / Scan can
/// leave 911 and Aid. Owner pages have no Help row — content starts
/// under the status bar.
struct PageHelpChrome<Trailing: View>: View {
    @Environment(\.isScannerSession) private var isScannerSession
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        if isScannerSession {
            HStack(alignment: .center, spacing: 12) {
                ScannerBackButton()
                Spacer(minLength: 0)
                trailing()
            }
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .center)
            .padding(.horizontal, RedMedChrome.pagePadX)
            .padding(.top, 16)
            .padding(.bottom, 8)
            .redmedTopChromeFill()
        }
    }
}

extension PageHelpChrome where Trailing == EmptyView {
    init() {
        self.trailing = { EmptyView() }
    }
}

/// Local Help cover so the tap-page Help button can present policies.
private struct PresentsOwnerHelp: ViewModifier {
    @State private var showHelp = false
    @Environment(\.isScannerSession) private var isScannerSession
    @EnvironmentObject private var profile: ProfileData

    func body(content: Content) -> some View {
        content
            .environment(\.ownerHelpOpen, $showHelp)
            .fullScreenCover(isPresented: $showHelp) {
                HelpMenuView(onOpenNFC: nil)
                    .environmentObject(profile)
                    .environment(\.isScannerSession, isScannerSession)
                    .presentationBackground(Color.redmedBg)
            }
    }
}

extension View {
    func presentsOwnerHelp() -> some View {
        modifier(PresentsOwnerHelp())
    }
}

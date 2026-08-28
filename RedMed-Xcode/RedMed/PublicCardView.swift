import SwiftUI

private struct ScannerSessionKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ScannerDismissKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
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

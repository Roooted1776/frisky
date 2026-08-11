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

/// Passerby / rescuer shell (ped / EMS).
///
/// Permanent product rule — tabs are **RedMed · 911 · Aid** only:
/// **no Edit**, **no NFC**. Mirrors bracelet tap page `get.html#d=…`
/// (owner edit + NFC write live in the owner app). Payload stays in `#d=`.
/// Holds a **snapshot** of the profile so scanner UI cannot mutate owner data.
/// Tap-to-view: no Face ID / biometrics. No brightness / audio unless the
/// owner phone separately arms crash / SOS survival (this shell does not).
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
/// Same `ChromeTextAction` as owner Edit — accent red, page-bg fill, 18 regular.
struct ScannerBackButton: View {
    @Environment(\.scannerDismiss) private var scannerDismiss

    var body: some View {
        if let scannerDismiss {
            ChromeTextAction(title: "Back", action: scannerDismiss)
        }
    }
}

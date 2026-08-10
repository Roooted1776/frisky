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

    /// Optional Close action when the scanner shell is presented over the owner app.
    var scannerDismiss: (() -> Void)? {
        get { self[ScannerDismissKey.self] }
        set { self[ScannerDismissKey.self] = newValue }
    }
}

/// Same app shell as `ContentView` for people who scan (ped / EMS):
/// **RedMed + 911 + Aid** — all three viewable, **no Edit**.
/// This mirrors the bracelet NFC tap (`card.html#d=…`) that strangers open
/// in a browser once NFC write is unarchived — keep them in sync.
/// Holds a **snapshot** of the profile so scanner UI cannot mutate owner data.
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

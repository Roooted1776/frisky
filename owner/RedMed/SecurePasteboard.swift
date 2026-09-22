import UIKit
import UniformTypeIdentifiers

/// App-local pasteboard writes. Coordinates expire (default 10 min for GPS copy)
/// and stay off Universal Clipboard. Erase clears our last write.
enum SecurePasteboard {
    /// Marks items this app wrote so `clear()` does not wipe another app's clipboard.
    private static let markerType = "com.redmed.pasteboard"

    /// Copies GPS coordinates as pasteable plain text (`lat, lon`).
    /// Local to this device (not Universal Clipboard). Expires; not wiped on
    /// background — leaving the app to paste into Phone / Messages / Maps is the point.
    static func copyCoordinates(_ string: String, lifetimeSeconds: TimeInterval = 600) {
        copyEphemeral(string, lifetimeSeconds: lifetimeSeconds)
    }

    /// Copies plain text that expires and stays local to this device pasteboard
    /// (not shared to Universal Clipboard / other devices).
    static func copyEphemeral(_ string: String, lifetimeSeconds: TimeInterval = 60) {
        let expiration = Date().addingTimeInterval(lifetimeSeconds)
        UIPasteboard.general.setItems(
            [[
                UTType.utf8PlainText.identifier: string,
                UTType.plainText.identifier: string,
                markerType: true
            ]],
            options: [
                .localOnly: true,
                .expirationDate: expiration
            ]
        )
    }

    /// Drops RedMed's last `copyEphemeral` write only. Leaves the system
    /// clipboard alone if the owner copied something else.
    static func clear() {
        let board = UIPasteboard.general
        guard board.contains(pasteboardTypes: [markerType]) else { return }
        board.items = []
    }
}

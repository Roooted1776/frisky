import UIKit
import UniformTypeIdentifiers

/// Short-lived, app-local pasteboard writes — never leave PHI/coords sitting on
/// the general pasteboard for other apps after the user backgrounds RedMed.
enum SecurePasteboard {
    /// Marks items this app wrote so `clear()` does not wipe another app's clipboard.
    private static let markerType = "com.redmed.pasteboard"

    /// Copies plain text that expires and stays local to this device pasteboard
    /// (not shared to Universal Clipboard / other devices).
    static func copyEphemeral(_ string: String, lifetimeSeconds: TimeInterval = 60) {
        let expiration = Date().addingTimeInterval(lifetimeSeconds)
        UIPasteboard.general.setItems(
            [[
                UTType.utf8PlainText.identifier: string,
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

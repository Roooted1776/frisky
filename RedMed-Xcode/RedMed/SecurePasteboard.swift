import UIKit
import UniformTypeIdentifiers

/// Short-lived, app-local pasteboard writes — never leave PHI/coords sitting on
/// the general pasteboard for other apps after the user backgrounds RedMed.
enum SecurePasteboard {
    /// Copies plain text that expires and stays local to this device pasteboard
    /// (not shared to Universal Clipboard / other devices).
    static func copyEphemeral(_ string: String, lifetimeSeconds: TimeInterval = 60) {
        let expiration = Date().addingTimeInterval(lifetimeSeconds)
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: string]],
            options: [
                .localOnly: true,
                .expirationDate: expiration
            ]
        )
    }

    static func clear() {
        UIPasteboard.general.items = []
    }
}

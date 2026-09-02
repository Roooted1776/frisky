import Foundation
import CoreLocation
import UIKit
import Combine

/// Location-denied status. Do not present When-In-Use from Agree — the user
/// already chose Location on Before You Continue. Find Help / hospitals
/// request the system sheet when GPS actually starts. Face ID is never involved.
final class LocationAccessSuggester: ObservableObject {
    static let shared = LocationAccessSuggester()

    /// True when iOS Location is denied/restricted — show Open Settings, no RedMed gate.
    @Published private(set) var mustOpenSettings = false

    private init() {}

    /// Read authorization without presenting the system sheet.
    /// A throwaway `CLLocationManager` is used only to read
    /// `authorizationStatus` — never retained, never given a delegate —
    /// so `locationd` is not kept awake across every Face ID → consent
    /// paint. The old retained manager+delegate did that, and Xcode's
    /// hang checkers paused Debug-on-device during that hardware init.
    func refresh() {
        apply(CLLocationManager().authorizationStatus)
    }

    private func apply(_ status: CLAuthorizationStatus) {
        switch status {
        case .denied, .restricted:
            mustOpenSettings = true
        default:
            mustOpenSettings = false
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

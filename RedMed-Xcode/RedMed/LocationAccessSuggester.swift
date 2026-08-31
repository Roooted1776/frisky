import Foundation
import CoreLocation
import UIKit
import Combine

/// Location-denied status, plus the one system When-In-Use prompt after Agree.
/// Find Help / nearby hospitals still start updates when Location is on — they
/// must not add a second in-app location wall. Face ID is never involved.
final class LocationAccessSuggester: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationAccessSuggester()

    /// True when iOS Location is denied/restricted — show Open Settings, no RedMed gate.
    @Published private(set) var mustOpenSettings = false

    /// Retained only so `requestWhenInUseAuthorization` can present the system sheet.
    /// Not used for continuous GPS (Find Help / NearbyHospitals own that).
    private var promptManager: CLLocationManager?

    private override init() {
        super.init()
    }

    /// Read authorization without presenting the system sheet.
    /// A throwaway `CLLocationManager` is used only to read
    /// `authorizationStatus` — never retained, never given a delegate —
    /// so `locationd` is not kept awake across every Face ID → consent
    /// paint. The old retained manager+delegate did that, and Xcode's
    /// hang checkers paused Debug-on-device during that hardware init.
    func refresh() {
        apply((promptManager ?? CLLocationManager()).authorizationStatus)
    }

    /// After Before-you-continue Agree: fire iOS's When-In-Use sheet once if
    /// Location is on and status is still `.notDetermined`.
    /// Cannot skip the system sheet. Does nothing if already determined or Location is off.
    func requestWhenInUseIfNeeded() {
        guard AppSettings.locationEnabled else { return }
        if promptManager == nil {
            let created = CLLocationManager()
            created.delegate = self
            promptManager = created
        }
        guard let m = promptManager else { return }
        apply(m.authorizationStatus)
        if m.authorizationStatus == .notDetermined {
            m.requestWhenInUseAuthorization()
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        apply(manager.authorizationStatus)
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

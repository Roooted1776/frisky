import Foundation
import CoreLocation
import UIKit

/// Asks for When-In-Use on first launch after install.
/// Does **not** start GPS updates — Find 911 / hospitals still start location only when visible.
final class LocationInstallPrompt: NSObject, CLLocationManagerDelegate {
    static let shared = LocationInstallPrompt()

    private let manager = CLLocationManager()
    private var didAskThisProcess = false

    private override init() {
        super.init()
        manager.delegate = self
    }

    /// System dialog once while status is `.notDetermined`. Safe to call repeatedly.
    func askIfNeeded() {
        guard !didAskThisProcess else { return }
        guard manager.authorizationStatus == .notDetermined else { return }
        didAskThisProcess = true
        manager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Intentional no-op: install prompt only requests auth; no updates here.
    }
}

/// Grabs a one-shot GPS fix, then opens Messages pre-filled with a maps link
/// to the emergency contact's phone number (parsed from their detail string).
class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var pendingContactDetail: String?

    override init() {
        super.init()
        manager.delegate = self
    }

    func requestAndSend(to contactDetail: String?) {
        pendingContactDetail = contactDetail
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        let url = "https://maps.google.com/?q=\(loc.coordinate.latitude),\(loc.coordinate.longitude)"
        let digits = (pendingContactDetail ?? "").filter(\.isNumber)
        let body = "This is my current location: \(url)"
        guard let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let smsURLString = digits.isEmpty ? "sms:&body=\(encodedBody)" : "sms:\(digits)&body=\(encodedBody)"
        if let smsURL = URL(string: smsURLString) {
            UIApplication.shared.open(smsURL)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silently ignore — user can retry.
    }
}

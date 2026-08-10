import Foundation
import CoreLocation
import UIKit

/// Single app-wide GPS service. Starts at launch so Find 911 has coords ready.
final class EmergencyLocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var location: CLLocation?
    @Published private(set) var authorizationDenied = false

    private let manager = CLLocationManager()
    private var pendingSMSContact: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.requestWhenInUseAuthorization()
        resumeUpdates()
    }

    func sendLocationSMS(to contactDetail: String?) {
        pendingSMSContact = contactDetail
        if let loc = location {
            openSMS(with: loc, contactDetail: contactDetail)
            pendingSMSContact = nil
            return
        }
        if isAuthorized {
            manager.requestLocation()
        } else if authorizationDenied, let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func resumeUpdates() {
        guard isAuthorized else { return }
        authorizationDenied = false
        manager.startUpdatingLocation()
    }

    private var isAuthorized: Bool {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: return true
        default: return false
        }
    }

    private func openSMS(with loc: CLLocation, contactDetail: String?) {
        let url = "https://maps.google.com/?q=\(loc.coordinate.latitude),\(loc.coordinate.longitude)"
        let digits = (contactDetail ?? "").filter(\.isNumber)
        let body = "This is my current location: \(url)"
        guard let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let smsURLString = digits.isEmpty ? "sms:&body=\(encodedBody)" : "sms:\(digits)&body=\(encodedBody)"
        if let smsURL = URL(string: smsURLString) {
            UIApplication.shared.open(smsURL)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            authorizationDenied = false
            resumeUpdates()
            if pendingSMSContact != nil {
                manager.requestLocation()
            }
        case .denied, .restricted:
            authorizationDenied = true
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        location = loc
        if pendingSMSContact != nil {
            openSMS(with: loc, contactDetail: pendingSMSContact)
            pendingSMSContact = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if pendingSMSContact != nil, let loc = manager.location {
            openSMS(with: loc, contactDetail: pendingSMSContact)
            pendingSMSContact = nil
        }
    }
}

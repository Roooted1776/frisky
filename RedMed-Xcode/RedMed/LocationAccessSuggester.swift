import Foundation
import CoreLocation
import UIKit
import Combine

/// Location-denied status only. Never prompts.
/// `CLLocationManager.requestWhenInUseAuthorization` runs from Find Help /
/// nearby hospitals when Location is enabled — not from Help chrome.
final class LocationAccessSuggester: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationAccessSuggester()

    private var manager: CLLocationManager?

    /// True when iOS Location is denied/restricted — show Open Settings, no RedMed gate.
    @Published private(set) var mustOpenSettings = false

    private override init() {
        super.init()
    }

    @discardableResult
    private func ensureManager() -> CLLocationManager {
        if let manager { return manager }
        let m = CLLocationManager()
        m.delegate = self
        manager = m
        return m
    }

    /// Read authorization without presenting the system sheet.
    func refresh() {
        let m = ensureManager()
        apply(m.authorizationStatus)
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

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if Thread.isMainThread {
            apply(status)
        } else {
            DispatchQueue.main.async { [weak self] in self?.apply(status) }
        }
    }
}

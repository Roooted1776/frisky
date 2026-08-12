import Foundation
import CoreLocation
import UIKit
import Combine

/// Optional Location nudge — surfaced from Help → Settings only.
/// Does **not** run at cold launch — no `CLLocationManager` until Settings
/// or Find Help (when Location is enabled) needs it.
final class LocationAccessSuggester: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationAccessSuggester()

    private var manager: CLLocationManager?

    @Published private(set) var needsSuggestion = false
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

    /// Call when Find Help becomes visible — creates the manager lazily.
    func prepareForFindHelp() {
        let m = ensureManager()
        apply(m.authorizationStatus)
    }

    func refresh() {
        guard let manager else {
            needsSuggestion = false
            mustOpenSettings = false
            return
        }
        apply(manager.authorizationStatus)
    }

    private func apply(_ status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            needsSuggestion = false
            mustOpenSettings = false
        case .denied, .restricted:
            needsSuggestion = true
            mustOpenSettings = true
        case .notDetermined:
            needsSuggestion = true
            mustOpenSettings = false
        @unknown default:
            needsSuggestion = true
            mustOpenSettings = false
        }
    }

    func primaryAction() {
        let m = ensureManager()
        apply(m.authorizationStatus)
        if mustOpenSettings {
            openSettings()
        } else {
            m.requestWhenInUseAuthorization()
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

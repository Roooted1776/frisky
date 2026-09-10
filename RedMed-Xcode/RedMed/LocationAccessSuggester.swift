import Foundation
import CoreLocation
import UIKit
import Combine

/// Location-denied status. Agree turns Location on. After post-Agree Face ID,
/// present When-In-Use once so 911 is not blocked by Apple's Allow sheet.
/// Does not start GPS — Find Help / hospitals still start updates. Do not
/// request from `@main`, from Agree (would stack with Face ID), or from Help.
final class LocationAccessSuggester: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationAccessSuggester()

    /// True when iOS Location is denied/restricted — show Open Settings, no RedMed gate.
    @Published private(set) var mustOpenSettings = false

    /// Retained only while the When-In-Use sheet is outstanding. Dropped
    /// after the status is determined so `locationd` is not kept awake.
    private var promptManager: CLLocationManager?
    /// One status reader — recreating `CLLocationManager()` on every
    /// Refresh / 911 appear wakes `locationd` for a throwaway. Reuse.
    private lazy var statusManager = CLLocationManager()

    private override init() {
        super.init()
    }

    /// Read authorization without presenting the system sheet.
    /// Uses a shared reader manager (no delegate, never starts GPS).
    func refresh() {
        apply(statusManager.authorizationStatus)
    }

    /// Present When-In-Use if still `.notDetermined`. Call after Face ID
    /// succeeds. Does not start GPS.
    func requestWhenInUseIfNeeded() {
        guard AppSettings.locationEnabled else { return }
        if promptManager != nil { return }
        let status = statusManager.authorizationStatus
        switch status {
        case .notDetermined:
            let m = CLLocationManager()
            m.delegate = self
            promptManager = m
            m.requestWhenInUseAuthorization()
        default:
            apply(status)
        }
    }

    private func apply(_ status: CLAuthorizationStatus) {
        let denied = status == .denied || status == .restricted
        if Thread.isMainThread {
            mustOpenSettings = denied
        } else {
            DispatchQueue.main.async { self.mustOpenSettings = denied }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        apply(status)
        if status != .notDetermined {
            promptManager = nil
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }
}

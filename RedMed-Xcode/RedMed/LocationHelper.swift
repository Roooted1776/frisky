import Foundation
import CoreLocation
import UIKit
import SwiftUI
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

/// Kept for reuse; Find Help no longer shows this — Location lives in Settings.
struct LocationSuggestionBanner: View {
    @ObservedObject private var suggester = LocationAccessSuggester.shared

    var body: some View {
        Group {
            if suggester.needsSuggestion {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.redmedAccent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Location suggested")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.redmedDark)
                        Text("Allow Location so Find Help can show exact GPS for dispatch.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.redmedMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 4)
                    Button(suggester.mustOpenSettings ? "Settings" : "Allow") {
                        suggester.primaryAction()
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.redmedAccent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.redmedAccent.opacity(0.08))
                .overlay(Rectangle().fill(Color.redmedAccent.opacity(0.2)).frame(height: 1), alignment: .bottom)
            }
        }
        .onAppear { suggester.prepareForFindHelp() }
    }
}

/// Grabs a one-shot GPS fix, then opens Messages pre-filled with a maps link
/// to the emergency contact's phone number.
class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var manager: CLLocationManager?
    private var pendingPhone: String?

    func requestAndSend(toPhone phone: String?) {
        pendingPhone = phone
        let m: CLLocationManager
        if let existing = manager {
            m = existing
        } else {
            let created = CLLocationManager()
            created.delegate = self
            manager = created
            m = created
        }
        m.requestWhenInUseAuthorization()
        if m.authorizationStatus == .authorizedWhenInUse || m.authorizationStatus == .authorizedAlways {
            m.requestLocation()
        }
    }

    /// Legacy: parse digits out of a combined `Relationship · phone` detail string.
    func requestAndSend(to contactDetail: String?) {
        requestAndSend(toPhone: contactDetail)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard manager.authorizationStatus == .authorizedWhenInUse
                || manager.authorizationStatus == .authorizedAlways else { return }
        manager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        let url = "https://maps.google.com/?q=\(loc.coordinate.latitude),\(loc.coordinate.longitude)"
        let digits = (pendingPhone ?? "").filter { $0.isNumber || $0 == "+" }
        let body = "This is my current location: \(url)"
        guard let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return }
        let smsURLString = digits.isEmpty ? "sms:&body=\(encodedBody)" : "sms:\(digits)&body=\(encodedBody)"
        guard let smsURL = URL(string: smsURLString) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(smsURL, options: [:], completionHandler: nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silently ignore — user can retry.
    }
}

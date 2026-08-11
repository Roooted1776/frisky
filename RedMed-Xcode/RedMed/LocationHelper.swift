import Foundation
import CoreLocation
import UIKit
import SwiftUI
import Combine

/// Optional Location nudge for Find Help only.
/// Does **not** run at cold launch — no `CLLocationManager` until Find Help
/// (or an explicit Allow) needs it. Never gates or replaces the main tabs.
final class LocationAccessSuggester: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationAccessSuggester()

    private var manager: CLLocationManager?

    @Published private(set) var needsSuggestion = false
    @Published private(set) var mustOpenSettings = false

    private override init() {
        super.init()
        // No CLLocationManager here — creating one at launch can surface the
        // system Location sheet / locationd work before the owner UI is ready.
    }

    private func ensureManager() -> CLLocationManager {
        if let manager { return manager }
        let m = CLLocationManager()
        m.delegate = self
        manager = m
        return m
    }

    func refresh() {
        // Without a manager yet, treat as undecided but do not prompt.
        guard manager != nil || CLLocationManager.locationServicesEnabled() else {
            needsSuggestion = true
            mustOpenSettings = false
            return
        }
        let status = manager?.authorizationStatus ?? CLLocationManager().authorizationStatus
        apply(status)
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

    /// Banner / Find Help only — never call from `@main` / first paint of RedMed.
    func suggestIfNeeded() {
        refresh()
    }

    func primaryAction() {
        let m = ensureManager()
        refresh()
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

/// Shown on Find Help only — never on cold launch / RedMed tab.
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
        .onAppear { suggester.suggestIfNeeded() }
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
        guard let smsURL = URL(string: smsURLString) else { return }
        DispatchQueue.main.async {
            UIApplication.shared.open(smsURL, options: [:], completionHandler: nil)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silently ignore — user can retry.
    }
}

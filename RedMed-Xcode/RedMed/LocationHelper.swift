import Foundation
import CoreLocation
import UIKit
import SwiftUI
import Combine

/// Keeps suggesting Location until When-In-Use (or Always) is granted.
/// Does **not** start GPS updates — Find 911 still starts updates only when visible.
final class LocationAccessSuggester: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationAccessSuggester()

    private let manager = CLLocationManager()

    /// True when the owner app should keep suggesting Location.
    @Published private(set) var needsSuggestion = false
    /// Denied/restricted — only Settings can fix it.
    @Published private(set) var mustOpenSettings = false

    private override init() {
        super.init()
        manager.delegate = self
        refresh()
    }

    func refresh() {
        switch manager.authorizationStatus {
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

    /// Call on launch / foreground. System dialog if undecided; banner stays until granted.
    func suggestIfNeeded() {
        refresh()
        guard needsSuggestion else { return }
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func primaryAction() {
        refresh()
        if mustOpenSettings {
            openSettings()
        } else {
            manager.requestWhenInUseAuthorization()
        }
    }

    func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            self?.refresh()
        }
    }
}

/// Always-visible nudge until Location is allowed.
struct LocationSuggestionBanner: View {
    @ObservedObject private var suggester = LocationAccessSuggester.shared

    var body: some View {
        if suggester.needsSuggestion {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "location.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.redmedAccent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Location suggested")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.redmedDark)
                    Text("Allow Location so Find 911 can show exact GPS for dispatch.")
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

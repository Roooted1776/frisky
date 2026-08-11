import Foundation
import CoreLocation
import UIKit
import SwiftUI
import Combine

/// Suggests Location until When-In-Use (or Always) is granted.
/// Does **not** gate app launch and does **not** start GPS updates —
/// Find Help still starts updates only when that tab is visible.
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

    /// Refresh banner state on foreground. Does **not** auto-present the system
    /// dialog — first launch stays on the main tabs. Authorization is requested
    /// when the user taps Allow on the banner or opens Find Help.
    func suggestIfNeeded() {
        refresh()
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
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if Thread.isMainThread {
            refresh()
        } else {
            DispatchQueue.main.async { [weak self] in self?.refresh() }
        }
    }
}

/// Always-visible nudge until Location is allowed. Never replaces the main tabs.
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

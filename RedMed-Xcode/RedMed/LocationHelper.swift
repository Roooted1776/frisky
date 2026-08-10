import Foundation
import CoreLocation
import UIKit
import SwiftUI
import Combine

/// Gates the owner app until Location has been asked, then keeps suggesting
/// until When-In-Use (or Always) is granted.
/// Does **not** start GPS updates — Find 911 still starts updates only when visible.
final class LocationAccessSuggester: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationAccessSuggester()

    private let manager = CLLocationManager()

    /// False while undecided — main tabs stay hidden until the system prompt is answered.
    @Published private(set) var canOpenApp = false
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
            canOpenApp = true
            needsSuggestion = false
            mustOpenSettings = false
        case .denied, .restricted:
            // Asked and answered — open the app; banner nudges Settings.
            canOpenApp = true
            needsSuggestion = true
            mustOpenSettings = true
        case .notDetermined:
            canOpenApp = false
            needsSuggestion = true
            mustOpenSettings = false
        @unknown default:
            canOpenApp = false
            needsSuggestion = true
            mustOpenSettings = false
        }
    }

    /// System dialog while undecided. Safe to call repeatedly; does not start GPS.
    func askIfNeeded() {
        refresh()
        guard manager.authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// Call on foreground once the app is open. Banner stays until granted.
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

/// Shown instead of the main tabs until Location has been asked (Allow / Don't Allow).
struct LocationLaunchGateView: View {
    @ObservedObject private var suggester = LocationAccessSuggester.shared

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "location.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundColor(.redmedAccent)
            Text("RedMed")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.redmedDark)
            Text("Allow Location so Find 911 can show exact GPS for dispatch.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.redmedMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Allow Location") {
                suggester.primaryAction()
            }
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.redmedAccent)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 32)
            .padding(.top, 8)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.redmedBg.ignoresSafeArea())
        .onAppear {
            suggester.askIfNeeded()
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

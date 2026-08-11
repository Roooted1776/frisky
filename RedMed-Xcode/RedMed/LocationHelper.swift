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

/// Legacy helper retained for Find Help banner wiring only.
/// Location SMS egress is disabled — Call is dial-only; coords use SecurePasteboard.
class LocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    private var manager: CLLocationManager?

    func requestAndSend(toPhone phone: String?) {
        // Intentionally no-op: never auto-SMS maps links or profile data.
        _ = phone
    }

    func requestAndSend(to contactDetail: String?) {
        requestAndSend(toPhone: contactDetail)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {}
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

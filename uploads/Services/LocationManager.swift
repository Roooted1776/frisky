import CoreLocation

/// Not @MainActor: CLLocationManager delegate callbacks aren't guaranteed
/// to land on the main thread, so @Published mutations are explicitly
/// hopped to main.
final class LocationManager: NSObject, ObservableObject {
    @Published var coordinate: CLLocationCoordinate2D?
    @Published var accuracy: CLLocationAccuracy?
    @Published var altitude: CLLocationDistance?
    @Published var locationTimestamp: Date?
    @Published var errorMessage: String?
    /// True compass heading in degrees (0 = north), or nil if the device has
    /// no magnetometer or heading data hasn't arrived yet. This is real
    /// on-device compass data — not satellite position or pointing guidance,
    /// which no third-party app can access (see LocationView's comment).
    @Published var heading: CLLocationDirection?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
    }

    func requestLocation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        case .denied, .restricted:
            errorMessage = "Location access is off. Enable it in Settings → Privacy & Security → Location Services → RedMed."
        @unknown default:
            break
        }
    }

    /// Call when the Find 911 tab is no longer visible. SwiftUI's TabView
    /// keeps every tab's view alive, so without this the GPS radio (and
    /// magnetometer) keep polling continuously in the background on every
    /// other tab — pure battery drain during exactly the situation where
    /// battery life matters.
    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.errorMessage = "Location access is off. Enable it in Settings → Privacy & Security → Location Services → RedMed."
            }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        DispatchQueue.main.async {
            self.coordinate = loc.coordinate
            self.accuracy = loc.horizontalAccuracy
            self.altitude = loc.verticalAccuracy >= 0 ? loc.altitude : nil
            self.locationTimestamp = loc.timestamp
            self.errorMessage = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let value = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        DispatchQueue.main.async {
            self.heading = value
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.errorMessage = "Couldn't get a GPS fix: \(error.localizedDescription)"
        }
    }
}

import Foundation
import CoreLocation
import MapKit

struct NearbyHospital: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let distanceMiles: Double
    let phone: String?
    let mapItem: MKMapItem
}

/// Finds real nearby hospitals/trauma centers using the device's current location + MapKit search.
class NearbyHospitalFinder: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var hospitals: [NearbyHospital] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private var manager: CLLocationManager?
    /// Bumped on every search() so a stale watchdog timeout can't clobber a later search's result.
    private var searchGeneration = 0

    func search() {
        searchGeneration += 1
        let generation = searchGeneration
        let begin = {
            self.isLoading = true
            self.errorMessage = nil
        }
        if Thread.isMainThread {
            begin()
        } else {
            DispatchQueue.main.async(execute: begin)
        }
        let m: CLLocationManager
        if let existing = manager {
            m = existing
        } else {
            let created = CLLocationManager()
            created.delegate = self
            manager = created
            m = created
        }
        switch m.authorizationStatus {
        case .notDetermined:
            m.requestWhenInUseAuthorization()
            scheduleTimeout(generation: generation)
        case .authorizedWhenInUse, .authorizedAlways:
            m.requestLocation()
            scheduleTimeout(generation: generation)
        case .denied, .restricted:
            let fail = {
                self.isLoading = false
                self.errorMessage = "Couldn't get your location. Check Location permission in Settings."
            }
            if Thread.isMainThread { fail() } else { DispatchQueue.main.async(execute: fail) }
        @unknown default:
            break
        }
    }

    /// Safety net: CLLocationManager / MKLocalSearch can hang without ever calling a delegate
    /// method back (e.g. GPS signal never resolves, simulator with no location set, a stuck
    /// permission prompt) — without this the spinner spins forever with no way to retry.
    private func scheduleTimeout(generation: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, self.searchGeneration == generation, self.isLoading else { return }
            self.isLoading = false
            self.errorMessage = "Couldn't find hospitals nearby. Try again."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isLoading else { return }
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            let fail = {
                self.isLoading = false
                self.errorMessage = "Couldn't get your location. Check Location permission in Settings."
            }
            if Thread.isMainThread { fail() } else { DispatchQueue.main.async(execute: fail) }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.first else { return }
        let request = MKLocalSearch.Request()
        // MapKit POI search — not a certified trauma Level I/II directory.
        request.naturalLanguageQuery = "hospital emergency room"
        request.region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 80000, longitudinalMeters: 80000)
        request.resultTypes = .pointOfInterest

        MKLocalSearch(request: request).start { [weak self] response, error in
            guard let self else { return }
            let apply = {
                self.isLoading = false
                if let error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                let items = response?.mapItems ?? []
                self.hospitals = items.map { item in
                    let itemLoc = item.placemark.location ?? loc
                    let miles = loc.distance(from: itemLoc) / 1609.34
                    return NearbyHospital(
                        name: item.name ?? "Hospital",
                        address: [item.placemark.locality, item.placemark.administrativeArea].compactMap { $0 }.joined(separator: ", "),
                        distanceMiles: miles,
                        phone: item.phoneNumber,
                        mapItem: item
                    )
                }
                .sorted { $0.distanceMiles < $1.distanceMiles }
                .prefix(8)
                .map { $0 }
            }
            if Thread.isMainThread {
                apply()
            } else {
                DispatchQueue.main.async(execute: apply)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let fail = {
            self.isLoading = false
            self.errorMessage = "Couldn't get your location. Check Location permission in Settings."
        }
        if Thread.isMainThread {
            fail()
        } else {
            DispatchQueue.main.async(execute: fail)
        }
    }
}

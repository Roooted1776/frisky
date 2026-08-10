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

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func search() {
        let begin = {
            self.isLoading = true
            self.errorMessage = nil
        }
        if Thread.isMainThread {
            begin()
        } else {
            DispatchQueue.main.async(execute: begin)
        }
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
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

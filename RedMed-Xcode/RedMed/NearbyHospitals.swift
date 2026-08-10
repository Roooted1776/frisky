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

/// MapKit hospital search from a known GPS fix (no separate location manager).
final class NearbyHospitalFinder: ObservableObject {
    @Published var hospitals: [NearbyHospital] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func search(near location: CLLocation?) {
        guard let loc = location else {
            isLoading = false
            errorMessage = "Waiting for GPS… allow Location when prompted."
            return
        }
        isLoading = true
        errorMessage = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "trauma center hospital emergency room"
        request.region = MKCoordinateRegion(center: loc.coordinate, latitudinalMeters: 80000, longitudinalMeters: 80000)
        request.resultTypes = .pointOfInterest

        MKLocalSearch(request: request).start { [weak self] response, error in
            guard let self else { return }
            DispatchQueue.main.async {
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
                if self.hospitals.isEmpty {
                    self.errorMessage = "No hospitals found nearby."
                }
            }
        }
    }
}

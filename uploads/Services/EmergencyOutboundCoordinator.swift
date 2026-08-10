import CoreLocation
import Foundation
import UIKit

/// Owns device-direct SOS outbound: optional third-party HTTPS, 911 dial, carrier SMS sheet.
/// Kept off `LocationView` so escaping fire hooks do not mutate View `@State`.
@MainActor
final class EmergencyOutboundCoordinator: ObservableObject {
    @Published var showSMSComposer = false
    @Published var smsBody = ""
    @Published var smsRecipients: [String] = []

    weak var locationManager: LocationManager?
    var profileProvider: () -> MedicalProfile = { MedicalProfile() }
    var contactPhonesProvider: () -> [String] = { [] }

    func fireOnline() {
        let profile = profileProvider()
        let coordinate = locationManager?.coordinate
        let accuracy = locationManager?.accuracy
        let heading = locationManager?.heading
        let altitude = locationManager?.altitude
        let timestamp = locationManager?.locationTimestamp
        let phones = contactPhonesProvider()

        Task {
            await ThirdPartyEmergencyClient.postAlert(
                event: "find911_sos",
                profile: profile,
                coordinate: coordinate,
                accuracy: accuracy,
                heading: heading,
                altitude: altitude,
                locationTimestamp: timestamp
            )
        }

        if let url = EmergencySummaryBuilder.call911URL {
            UIApplication.shared.open(url)
        }

        guard !phones.isEmpty else { return }
        smsRecipients = phones
        smsBody = EmergencySummaryBuilder.build(
            profile: profile,
            coordinate: coordinate,
            accuracy: accuracy,
            heading: heading,
            altitude: altitude,
            locationTimestamp: timestamp,
            isOffline: false
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.showSMSComposer = true
        }
    }
}

import CoreLocation
import Foundation

/// Device → third-party HTTPS only. No RedMed server.
/// When `AppConfig.thirdPartyEmergencyAlertURL` is empty, this is a no-op
/// (default ship state — does not change Find 911 dial/SMS behavior).
enum ThirdPartyEmergencyClient {
    struct AlertPayload: Encodable {
        var source: String
        var event: String
        var latitude: Double?
        var longitude: Double?
        var accuracyMeters: Double?
        var altitudeMeters: Double?
        var headingDegrees: Double?
        var locationAsOf: String?
        var name: String?
        var bloodType: String?
        var allergies: [String]
        var conditions: [String]
        var medications: [String]
        var mapsApple: String?
        var mapsGoogle: String?
    }

    static var isConfigured: Bool {
        let url = AppConfig.thirdPartyEmergencyAlertURL.trimmingCharacters(in: .whitespacesAndNewlines)
        return !url.isEmpty && URL(string: url) != nil
    }

    /// Fire-and-forget POST. Failures are swallowed so 911 / SMS still proceed.
    static func postAlert(
        event: String,
        profile: MedicalProfile,
        coordinate: CLLocationCoordinate2D?,
        accuracy: CLLocationAccuracy?,
        heading: CLLocationDirection?,
        altitude: CLLocationDistance?,
        locationTimestamp: Date?
    ) async {
        let raw = AppConfig.thirdPartyEmergencyAlertURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty, let url = URL(string: raw) else { return }

        let iso = ISO8601DateFormatter()
        var mapsApple: String?
        var mapsGoogle: String?
        if let coordinate {
            mapsApple = "https://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)"
            mapsGoogle = "https://maps.google.com/?q=\(coordinate.latitude),\(coordinate.longitude)"
        }

        let payload = AlertPayload(
            source: "RedMed",
            event: event,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            accuracyMeters: (accuracy ?? -1) > 0 ? accuracy : nil,
            altitudeMeters: altitude,
            headingDegrees: heading,
            locationAsOf: iso.string(from: locationTimestamp ?? Date()),
            name: profile.name.isEmpty ? nil : profile.name,
            bloodType: profile.blood.isEmpty ? nil : profile.blood,
            allergies: profile.allergies,
            conditions: profile.conditions,
            medications: profile.meds,
            mapsApple: mapsApple,
            mapsGoogle: mapsGoogle
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("RedMed-iOS", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 8
        let token = AppConfig.thirdPartyEmergencyAlertToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            request.httpBody = try JSONEncoder().encode(payload)
            _ = try await URLSession.shared.data(for: request)
        } catch {
            // Intentional: third-party outage must not block dial / SMS.
        }
    }
}

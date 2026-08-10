import CoreLocation

enum LocationFormatting {
    static func dms(latitude: Double, longitude: Double) -> String {
        "\(dmsComponent(latitude, isLat: true)) \(dmsComponent(longitude, isLat: false))"
    }

    static func coordsCopyText(latitude: Double, longitude: Double) -> String {
        String(format: "%.6f, %.6f\n%@", latitude, longitude, dms(latitude: latitude, longitude: longitude))
    }

    static func cardinal(for degrees: CLLocationDirection) -> String {
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return directions[Int((degrees / 45.0).rounded()) % 8]
    }

    private static func dmsComponent(_ decimal: Double, isLat: Bool) -> String {
        let absolute = abs(decimal)
        var degrees = Int(absolute)
        let minFloat = (absolute - Double(degrees)) * 60
        var minutes = Int(minFloat)
        var seconds = Int(round((minFloat - Double(minutes)) * 60))
        if seconds == 60 { seconds = 0; minutes += 1 }
        if minutes == 60 { minutes = 0; degrees += 1 }
        let direction = isLat ? (decimal >= 0 ? "N" : "S") : (decimal >= 0 ? "E" : "W")
        return "\(degrees)°\(minutes)'\(seconds)\"\(direction)"
    }
}

enum EmergencySummaryBuilder {
    // Cached once instead of created per call — LocationView recomputes
    // this summary on every GPS/heading update (several times a second
    // while facing changes), and DateFormatter construction is
    // comparatively expensive to do that often.
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    static func build(
        profile: MedicalProfile,
        coordinate: CLLocationCoordinate2D? = nil,
        accuracy: CLLocationAccuracy? = nil,
        heading: CLLocationDirection? = nil,
        altitude: CLLocationDistance? = nil,
        locationTimestamp: Date? = nil,
        isOffline: Bool = false
    ) -> String {
        var lines: [String] = ["EMERGENCY LOCATION — RedMed"]

        if isOffline {
            lines.append("Note: Caller may need native Emergency SOS via satellite if no cell service.")
        }

        if let coordinate {
            lines.append(String(format: "Decimal: %.6f, %.6f", coordinate.latitude, coordinate.longitude))
            lines.append("DMS: \(LocationFormatting.dms(latitude: coordinate.latitude, longitude: coordinate.longitude))")
            if let accuracy, accuracy > 0 {
                lines.append(String(format: "Accuracy: ±%.0f meters", accuracy))
            }
            if let heading {
                lines.append("Heading: \(Int(heading))° (\(LocationFormatting.cardinal(for: heading)))")
            }
            if let altitude {
                lines.append(String(format: "Altitude: %.0f m", altitude))
            }
            let timestamp = locationTimestamp ?? Date()
            lines.append("Location as of: \(timeFormatter.string(from: timestamp))")
            lines.append("Apple Maps: https://maps.apple.com/?ll=\(coordinate.latitude),\(coordinate.longitude)")
            lines.append("Google Maps: https://maps.google.com/?q=\(coordinate.latitude),\(coordinate.longitude)")
        } else {
            lines.append("Location: Tell dispatcher your location")
            lines.append("Location as of: \(timeFormatter.string(from: Date()))")
        }

        var medLines: [String] = []
        if !profile.name.isEmpty { medLines.append("Name: \(profile.name)") }
        if !profile.blood.isEmpty { medLines.append("Blood: \(profile.blood)") }
        if !profile.allergies.isEmpty { medLines.append("Allergies: \(profile.allergies.joined(separator: ", "))") }
        if !profile.conditions.isEmpty { medLines.append("Conditions: \(profile.conditions.joined(separator: ", "))") }
        if !profile.meds.isEmpty { medLines.append("Meds: \(profile.meds.joined(separator: ", "))") }
        if !medLines.isEmpty {
            lines.append("")
            lines.append("Medical:")
            lines.append(contentsOf: medLines)
        }

        return lines.joined(separator: "\n")
    }

    static func normalizedPhone(_ phone: String) -> String {
        phone.filter { $0.isNumber || $0 == "+" }
    }

    /// `telprompt:` asks iPhone to confirm before placing the call — required for in-app dialing.
    static func telURL(phone: String, prompt: Bool = true) -> URL? {
        let digits = normalizedPhone(phone)
        guard !digits.isEmpty else { return nil }
        let scheme = prompt ? "telprompt" : "tel"
        return URL(string: "\(scheme):\(digits)")
    }

    static var call911URL: URL? { telURL(phone: "911") }
}

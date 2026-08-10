import CoreLocation
import Foundation

/// Google reverse-geocoding has been removed for security (no third-party API
/// key ships with the app, and the app makes no calls to Google).
///
/// The trauma-center finder works entirely from the bundled static dataset;
/// GPS auto-region was a convenience-only enhancement. This stub is kept so
/// callers compile unchanged — it always returns `nil`, so the UI falls back
/// to manual state/county selection.
enum GoogleGeocoder {
    struct Region: Equatable {
        var state: String
        var county: String
    }

    /// Always returns `nil`: no API key, no network request.
    static func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> Region? {
        return nil
    }
}

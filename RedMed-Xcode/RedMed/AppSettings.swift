import Foundation

/// In-app Settings prefs (Help → Settings). Only haptic + location live here.
/// Brightness + locator siren arm only on crash / severe-impact detection.
enum AppSettings {
    static let locationEnabledKey = "redmed.locationEnabled"

    /// Find Help GPS. Default on; user can disable in Settings.
    static var locationEnabled: Bool {
        if UserDefaults.standard.object(forKey: locationEnabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: locationEnabledKey)
    }
}

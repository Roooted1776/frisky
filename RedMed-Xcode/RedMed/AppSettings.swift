import Foundation

/// In-app prefs (Before you continue). Only haptic + location live here.
/// Brightness + max volume + locator siren arm on crash / severe-impact or Find Help SOS.
enum AppSettings {
    static let locationEnabledKey = "redmed.locationEnabled"

    /// Find Help GPS. Default on; user can disable on Before you continue.
    static var locationEnabled: Bool {
        if UserDefaults.standard.object(forKey: locationEnabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: locationEnabledKey)
    }
}

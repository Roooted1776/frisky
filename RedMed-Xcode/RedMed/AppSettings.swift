import Foundation

/// In-app prefs. Haptic lives on Before you continue. Location is on as
/// part of Agree (no in-app Location toggle). Brightness + max volume +
/// locator siren arm on crash / severe-impact or Find Help SOS.
enum AppSettings {
    static let locationEnabledKey = "redmed.locationEnabled"

    /// Find Help GPS. Default on. Agree writes true. Off switch is iOS Settings.
    static var locationEnabled: Bool {
        if UserDefaults.standard.object(forKey: locationEnabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: locationEnabledKey)
    }
}

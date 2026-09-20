import Foundation

/// In-app prefs. Haptic feedback + Location toggles live in Help →
/// Settings (owner only); Agree also turns Location on. Brightness +
/// max volume + locator siren arm on crash / severe-impact or Find Help SOS.
enum AppSettings {
    static let locationEnabledKey = "redmed.locationEnabled"

    /// Find Help GPS. Default on. Agree writes true. Off switch is iOS Settings.
    static var locationEnabled: Bool {
        if UserDefaults.standard.object(forKey: locationEnabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: locationEnabledKey)
    }
}

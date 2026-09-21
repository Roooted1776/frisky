import Foundation

/// In-app prefs. Haptic feedback + Location toggles live in Help →
/// Settings (owner only); Agree to emergency terms auto-accepts Location
/// (writes true). Brightness + max volume + locator siren arm on crash /
/// severe-impact or Find Help SOS.
enum AppSettings {
    static let locationEnabledKey = "redmed.locationEnabled"

    /// Find Help GPS. Default on. Agree (including policy bump / Erase) writes
    /// true as part of emergency terms. Off switch is Help → Settings or iOS
    /// Settings. When-In-Use is requested once after Face ID when still
    /// `.notDetermined`.
    static var locationEnabled: Bool {
        if UserDefaults.standard.object(forKey: locationEnabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: locationEnabledKey)
    }
}

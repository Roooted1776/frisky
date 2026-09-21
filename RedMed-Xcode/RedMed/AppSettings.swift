import Foundation

/// In-app prefs. Haptic lives on Before you continue. Location is on as
/// part of Agree (no in-app Location toggle). Brightness + max volume +
/// locator siren arm on crash / severe-impact or Find Help SOS.
enum AppSettings {
    static let locationEnabledKey = "redmed.locationEnabled"

    /// Find Help GPS. In-app Location is always on after Agree. The Help →
    /// Settings toggle was removed; leftover `redmed.locationEnabled == false`
    /// had no UI recovery. iOS When-In-Use / Settings is the only off-switch.
    static var locationEnabled: Bool {
        migrateRemovedLocationToggle()
        return true
    }

    /// Unstick UserDefaults so leftover `@AppStorage` readers see on.
    /// Call from `@main` init before SwiftUI mounts.
    static func migrateRemovedLocationToggle() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: locationEnabledKey) as? Bool == false {
            defaults.set(true, forKey: locationEnabledKey)
        }
    }
}

import Foundation

/// In-app prefs (Before you continue). Haptic, location, and Face ID live here.
/// Brightness + max volume + locator siren arm on crash / severe-impact or Find Help SOS.
enum AppSettings {
    static let locationEnabledKey = "redmed.locationEnabled"
    static let faceIDEnabledKey = "redmed.faceIDEnabled"

    /// Find Help GPS. Default on; user can disable on Before you continue.
    static var locationEnabled: Bool {
        if UserDefaults.standard.object(forKey: locationEnabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: locationEnabledKey)
    }

    /// Face ID for Edit, Save, Erase. Default on. Does not disable the
    /// owner open/return lock (`OwnerAppLock` always evaluates).
    static var faceIDEnabled: Bool {
        if UserDefaults.standard.object(forKey: faceIDEnabledKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: faceIDEnabledKey)
    }
}

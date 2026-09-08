import Foundation
import os

/// Diagnostic-only `os_signpost` + cold-launch breadcrumbs.
/// Face ID: `faceIDEvaluate` spans `LAContext.evaluatePolicy`.
/// Cold launch: `coldMark` / `coldLaunchWindow` — Console.app filter
/// subsystem `com.redmed.app`, category `ColdLaunch`. Times are ms since
/// process start (first Swift mark). Cream sitting with **no** ColdLaunch
/// lines yet is still Xcode install / debugger attach — not app code.
enum RedMedSignpost {
    enum Interval {
        case coldLaunchWindow
        case faceIDEvaluate

        fileprivate var name: StaticString {
            switch self {
            case .coldLaunchWindow: return "ColdLaunchWindow"
            case .faceIDEvaluate: return "FaceIDEvaluate"
            }
        }
    }

    private static let signposter = OSSignposter(subsystem: "com.redmed.app", category: "AppLock")
    private static let lock = NSLock()
    private static var states: [String: OSSignpostIntervalState] = [:]

    /// Persistent breadcrumb for Face ID evaluate — `os_log` in Console.app
    /// (filter subsystem "com.redmed.app"). Cheap enough to leave in.
    private static let log = os.Logger(subsystem: "com.redmed.app", category: "AppLock")

    private static let coldLog = os.Logger(subsystem: "com.redmed.app", category: "ColdLaunch")
    /// Process-relative clock for cold marks. Set on first `coldMark` / `begin(.coldLaunchWindow)`.
    private static let t0Lock = NSLock()
    private static var t0: CFAbsoluteTime?

    static func trace(_ message: String) {
        log.notice("\(message, privacy: .public)")
    }

    /// `+NNN.Nms event` since first cold mark. No-op cost: one os_log.
    static func coldMark(_ event: String) {
        let now = CFAbsoluteTimeGetCurrent()
        t0Lock.lock()
        if t0 == nil { t0 = now }
        let start = t0 ?? now
        t0Lock.unlock()
        let ms = (now - start) * 1000
        coldLog.notice("+\(ms, format: .fixed(precision: 1))ms \(event, privacy: .public)")
    }

    /// No-ops if already begun — callers don't need to track their own state.
    static func begin(_ interval: Interval) {
        if interval == .coldLaunchWindow {
            coldMark("begin coldLaunchWindow")
        }
        lock.lock()
        defer { lock.unlock() }
        let key = "\(interval)"
        guard states[key] == nil else { return }
        states[key] = signposter.beginInterval(interval.name)
    }

    /// No-ops if never begun (or already ended).
    static func end(_ interval: Interval) {
        if interval == .coldLaunchWindow {
            coldMark("end coldLaunchWindow")
        }
        lock.lock()
        let key = "\(interval)"
        let state = states.removeValue(forKey: key)
        lock.unlock()
        guard let state else { return }
        signposter.endInterval(interval.name, state)
    }
}

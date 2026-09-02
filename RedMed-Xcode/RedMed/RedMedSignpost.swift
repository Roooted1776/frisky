import Foundation
import os

/// Diagnostic-only `os_signpost` markers for Face ID evaluate
/// (RedMed user view / Edit / Save / Erase). No behavior change.
/// `coldLaunchWindow` is unused after the launch lock was removed;
/// `faceIDEvaluate` still spans `LAContext.evaluatePolicy`.
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

    static func trace(_ message: String) {
        log.notice("\(message, privacy: .public)")
    }

    /// No-ops if already begun — callers don't need to track their own state.
    static func begin(_ interval: Interval) {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(interval)"
        guard states[key] == nil else { return }
        states[key] = signposter.beginInterval(interval.name)
    }

    /// No-ops if never begun (or already ended).
    static func end(_ interval: Interval) {
        lock.lock()
        let key = "\(interval)"
        let state = states.removeValue(forKey: key)
        lock.unlock()
        guard let state else { return }
        signposter.endInterval(interval.name, state)
    }
}

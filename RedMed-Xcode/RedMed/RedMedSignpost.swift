import Foundation
import os

/// Diagnostic-only `os_signpost` markers for the cold-launch / Face ID unlock
/// path — no behavior change, negligible overhead. Added because Instruments
/// reported high main-thread CPU "during the Face ID sheet" with no specific
/// symbol to act on.
///
/// To use: open Instruments' "Points of Interest" template (or add the
/// os_signpost instrument to a Time Profiler trace), reproduce the slow
/// launch, and look at the labeled intervals on the timeline:
/// - `coldLaunchWindow` spans the whole lock screen, from first appear to
///   the first UI resolution (either unlocked or the Proceed screen).
/// - `faceIDEvaluate` spans only the system `LAContext.evaluatePolicy` call.
///
/// If the CPU spike's time range sits inside `faceIDEvaluate`, it's Apple's
/// own Face ID / Neural Engine work, not RedMed's code. If it falls in the
/// gap around `faceIDEvaluate` but still inside `coldLaunchWindow`, that
/// points at something in RedMed's own unlock path worth digging into next.
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

    /// Persistent breadcrumb for diagnosing a stuck cold-launch lock screen
    /// after the fact — `os_log` output (unlike Instruments) is visible live
    /// in Console.app (device connected, filter subsystem "com.redmed.app",
    /// category "AppLock") without an attached Xcode debug session. Cheap
    /// enough to leave in permanently; only fires on the lock/unlock path.
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

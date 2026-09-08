import Foundation
import os

/// Diagnostic-only `os_signpost` + cold-launch breadcrumbs.
/// Face ID: `faceIDEvaluate` spans `LAContext.evaluatePolicy`.
/// Cold launch: Console.app → subsystem `com.redmed.app`, category `ColdLaunch`.
/// Times are ms since first Swift mark (`app.init`). Cream with **no**
/// ColdLaunch lines yet = Xcode install / debugger attach, not app code.
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

    /// Face ID evaluate breadcrumbs — filter subsystem `com.redmed.app`.
    private static let log = os.Logger(subsystem: "com.redmed.app", category: "AppLock")
    private static let coldLog = os.Logger(subsystem: "com.redmed.app", category: "ColdLaunch")

    private static let t0Lock = NSLock()
    private static var t0: CFAbsoluteTime?
    private static var didMarkFirstFrame = false

    static func trace(_ message: String) {
        log.notice("\(message, privacy: .public)")
    }

    /// `+NNN.Nms event` since first cold mark.
    static func coldMark(_ event: String) {
        let now = CFAbsoluteTimeGetCurrent()
        t0Lock.lock()
        if t0 == nil { t0 = now }
        let start = t0 ?? now
        t0Lock.unlock()
        let ms = (now - start) * 1000
        coldLog.notice("+\(ms, format: .fixed(precision: 1))ms \(event, privacy: .public)")
    }

    /// First SwiftUI frame after SplashBoard. Call once from LaunchRoot.
    /// Ends `coldLaunchWindow` (app.init → firstFrame).
    static func coldLaunchFirstFrameOnce() {
        t0Lock.lock()
        let already = didMarkFirstFrame
        if !already { didMarkFirstFrame = true }
        t0Lock.unlock()
        guard !already else { return }
        let accepted = ConsentSettings.hasAcceptedCurrent
        coldMark(
            accepted
                ? "firstFrame consent=\(ConsentSettings.currentVersion) → Face ID over Main"
                : "firstFrame consent pending (\(ConsentSettings.currentVersion)) → Before You Continue"
        )
        end(.coldLaunchWindow)
    }

    /// Main interactive (after cold Face ID — returning or post-Agree).
    static func coldLaunchMainReady(_ reason: String) {
        coldMark("mainReady \(reason)")
    }

    /// Alias at `@main` — starts `coldLaunchWindow` on `app.init`.
    static func coldLaunchMark(_ event: String) {
        if event == "app.init" {
            begin(.coldLaunchWindow)
        }
        coldMark(event)
    }

    static func begin(_ interval: Interval) {
        lock.lock()
        defer { lock.unlock() }
        let key = "\(interval)"
        guard states[key] == nil else { return }
        states[key] = signposter.beginInterval(interval.name)
    }

    static func end(_ interval: Interval) {
        lock.lock()
        let key = "\(interval)"
        let state = states.removeValue(forKey: key)
        lock.unlock()
        guard let state else { return }
        signposter.endInterval(interval.name, state)
    }
}

import UIKit

/// Forces screen brightness to 100% for the crash / severe-impact survival alarm only.
/// Saves the prior level and restores it when the hold is cancelled.
/// Simulator: property writes are harmless no-ops for hardware backlight.
@MainActor
enum BrightnessBoost {
    private static var savedBrightness: CGFloat?
    private static var savedIdleTimerDisabled: Bool?
    private static var survivalHold = false
    private static var foregroundObserver: NSObjectProtocol?
    private static var activeObserver: NSObjectProtocol?

    /// Crash / severe-impact arm — keeps max brightness even while backgrounded.
    static func beginSurvival() {
        if !survivalHold {
            savedBrightness = UIScreen.main.brightness
            savedIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
            survivalHold = true
            installLifecycleObservers()
        }
        applyBoost()
    }

    static func endSurvival() {
        guard survivalHold else { return }
        survivalHold = false
        removeLifecycleObservers()
        restoreSaved()
        savedBrightness = nil
        savedIdleTimerDisabled = nil
    }

    private static func installLifecycleObservers() {
        removeLifecycleObservers()
        let center = NotificationCenter.default
        foregroundObserver = center.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                guard survivalHold else { return }
                applyBoost()
            }
        }
        activeObserver = center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                guard survivalHold else { return }
                applyBoost()
            }
        }
    }

    private static func removeLifecycleObservers() {
        let center = NotificationCenter.default
        if let foregroundObserver {
            center.removeObserver(foregroundObserver)
            self.foregroundObserver = nil
        }
        if let activeObserver {
            center.removeObserver(activeObserver)
            self.activeObserver = nil
        }
    }

    private static func applyBoost() {
        UIScreen.main.brightness = 1.0
        UIApplication.shared.isIdleTimerDisabled = true
    }

    private static func restoreSaved() {
        if let savedBrightness {
            UIScreen.main.brightness = savedBrightness
        }
        if let savedIdleTimerDisabled {
            UIApplication.shared.isIdleTimerDisabled = savedIdleTimerDisabled
        }
    }
}

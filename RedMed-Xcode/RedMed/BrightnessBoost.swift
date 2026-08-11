import SwiftUI
import UIKit

/// Forces screen brightness to 100% for emergency visibility (scanner shell, Find Help,
/// crash survival alarm). Saves the prior level and restores it when hosts leave.
/// Simulator: property writes are harmless no-ops for hardware backlight.
@MainActor
enum BrightnessBoost {
    private static var savedBrightness: CGFloat?
    private static var savedIdleTimerDisabled: Bool?
    private static var activeCount = 0
    /// Crash / hard-impact hold — stays at 100% through background until cancelled.
    private static var survivalHold = false
    /// True when a boost is armed but temporarily restored for background/inactive.
    private static var pausedForBackground = false

    static func begin() {
        activeCount += 1
        guard activeCount == 1 else {
            if !pausedForBackground || survivalHold {
                applyBoost()
            }
            return
        }

        let screen = UIScreen.main
        savedBrightness = screen.brightness
        savedIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        pausedForBackground = false
        applyBoost()
    }

    static func end() {
        guard activeCount > 0 else { return }
        activeCount -= 1
        guard activeCount == 0 else { return }
        guard !survivalHold else {
            applyBoost()
            return
        }

        restoreSaved()
        savedBrightness = nil
        savedIdleTimerDisabled = nil
        pausedForBackground = false
    }

    /// Crash motion arm — keeps max brightness even while the app is backgrounded.
    static func beginSurvival() {
        if !survivalHold {
            if activeCount == 0 && savedBrightness == nil {
                savedBrightness = UIScreen.main.brightness
                savedIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
            }
            survivalHold = true
        }
        pausedForBackground = false
        applyBoost()
    }

    static func endSurvival() {
        guard survivalHold else { return }
        survivalHold = false
        if activeCount == 0 {
            restoreSaved()
            savedBrightness = nil
            savedIdleTimerDisabled = nil
            pausedForBackground = false
        } else {
            applyBoost()
        }
    }

    /// Restore user brightness while the app is not active so Home / other apps
    /// are not stuck at 100% (onDisappear does not run on background).
    /// Skipped while crash survival hold is active.
    static func pauseForBackground() {
        guard !survivalHold else {
            applyBoost()
            return
        }
        guard activeCount > 0, !pausedForBackground else { return }
        pausedForBackground = true
        restoreSaved()
    }

    /// Re-apply max brightness when returning to foreground with active hosts.
    static func resumeFromBackground() {
        guard activeCount > 0 || survivalHold else { return }
        pausedForBackground = false
        applyBoost()
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

private struct BrightnessBoostModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear { BrightnessBoost.begin() }
            .onDisappear { BrightnessBoost.end() }
            .onChange(of: scenePhase) { _, phase in
                switch phase {
                case .active:
                    BrightnessBoost.resumeFromBackground()
                case .inactive, .background:
                    BrightnessBoost.pauseForBackground()
                @unknown default:
                    BrightnessBoost.pauseForBackground()
                }
            }
    }
}

extension View {
    /// Auto-boosts brightness to 100% for visibility while this view is on screen.
    func maxBrightnessForVisibility() -> some View {
        modifier(BrightnessBoostModifier())
    }
}

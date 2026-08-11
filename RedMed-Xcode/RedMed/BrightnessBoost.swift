import SwiftUI
import UIKit

/// Forces screen brightness to 100% for emergency visibility (scanner shell, Find Help).
/// Saves the prior level and restores it when the hosting view leaves.
/// Simulator: property writes are harmless no-ops for hardware backlight.
@MainActor
enum BrightnessBoost {
    private static var savedBrightness: CGFloat?
    private static var savedIdleTimerDisabled: Bool?
    private static var activeCount = 0

    static func begin() {
        activeCount += 1
        guard activeCount == 1 else { return }

        let screen = UIScreen.main
        savedBrightness = screen.brightness
        savedIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled

        screen.brightness = 1.0
        UIApplication.shared.isIdleTimerDisabled = true
    }

    static func end() {
        guard activeCount > 0 else { return }
        activeCount -= 1
        guard activeCount == 0 else { return }

        if let savedBrightness {
            UIScreen.main.brightness = savedBrightness
        }
        if let savedIdleTimerDisabled {
            UIApplication.shared.isIdleTimerDisabled = savedIdleTimerDisabled
        }
        savedBrightness = nil
        savedIdleTimerDisabled = nil
    }
}

private struct BrightnessBoostModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onAppear { BrightnessBoost.begin() }
            .onDisappear { BrightnessBoost.end() }
            .onChange(of: scenePhase) { _, phase in
                // Keep max brightness while active and foregrounded.
                if phase == .active {
                    UIScreen.main.brightness = 1.0
                    UIApplication.shared.isIdleTimerDisabled = true
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

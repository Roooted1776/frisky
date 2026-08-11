import CoreMotion
import Foundation
import SwiftUI

/// On-device crash / hard-impact guard (CoreMotion only — no cloud, not Apple Crash Detection).
/// Arms full brightness + locator siren so rescuers can find the phone in life-or-death seconds.
@MainActor
final class CrashMotionGuard: ObservableObject {
    static let shared = CrashMotionGuard()

    @Published private(set) var isArmed = false

    /// Hard impact peak (user-acceleration magnitude in g).
    private static let impactPeakG: Double = 4.5
    /// Sustained jolt floor (g) — ejection / tumble.
    private static let sustainPeakG: Double = 2.8
    private static let sustainSeconds: TimeInterval = 0.9
    private static let cooldownSeconds: TimeInterval = 45

    private let manager = CMMotionManager()
    private var elevatedSince: Date?
    private var lastArmAt: Date?
    private var isRunning = false

    private init() {}

    /// Start after first paint so cold launch stays light. Owner device only.
    func startMonitoring() {
        guard !isRunning else { return }
        guard manager.isDeviceMotionAvailable else { return }
        isRunning = true
        elevatedSince = nil
        manager.deviceMotionUpdateInterval = 1.0 / 50.0
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.evaluate(userAcceleration: motion.userAcceleration)
        }
    }

    func stopMonitoring() {
        guard isRunning else { return }
        isRunning = false
        manager.stopDeviceMotionUpdates()
        elevatedSince = nil
    }

    /// False-positive cancel — restores brightness/siren holds.
    func disarm() {
        guard isArmed else { return }
        isArmed = false
        BrightnessBoost.endSurvival()
        LocatorBeacon.endSurvival()
    }

    private func arm() {
        guard !isArmed else { return }
        isArmed = true
        lastArmAt = Date()
        elevatedSince = nil
        BrightnessBoost.beginSurvival()
        LocatorBeacon.beginSurvival()
    }

    private func evaluate(userAcceleration accel: CMAcceleration) {
        if isArmed { return }
        if let last = lastArmAt, Date().timeIntervalSince(last) < Self.cooldownSeconds {
            return
        }

        let magnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)

        // Single hard spike (crash / drop impact).
        if magnitude >= Self.impactPeakG {
            arm()
            return
        }

        // Sustained high-g tumble / ejection.
        if magnitude >= Self.sustainPeakG {
            if elevatedSince == nil {
                elevatedSince = Date()
            } else if let since = elevatedSince,
                      Date().timeIntervalSince(since) >= Self.sustainSeconds {
                arm()
            }
        } else {
            elevatedSince = nil
        }
    }
}

/// Full-screen cancel surface while crash survival alarm is armed.
struct CrashSurvivalOverlay: View {
    @ObservedObject private var guardMonitor = CrashMotionGuard.shared

    var body: some View {
        if guardMonitor.isArmed {
            ZStack {
                Color.redmedAccent.ignoresSafeArea()
                VStack(spacing: 20) {
                    Spacer(minLength: 40)
                    Image(systemName: "light.beacon.max.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.white)
                    Text("IMPACT DETECTED")
                        .font(.system(size: 28, weight: .heavy))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("Full brightness + locate-me siren are on so rescuers can find this iPhone. Local sensors only — not Apple Crash Detection.")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white.opacity(0.92))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                    Spacer()
                    Button {
                        guardMonitor.disarm()
                    } label: {
                        Text("I'm OK — cancel alarm")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.redmedAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 40)
                }
            }
            .transition(.opacity)
            .zIndex(2000)
            .accessibilityAddTraits(.isModal)
        }
    }
}

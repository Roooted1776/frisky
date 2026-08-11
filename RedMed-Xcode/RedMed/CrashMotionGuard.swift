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

/// Cancel card shown on Aid while crash survival alarm is armed.
/// Matches pane / InfoCard chrome (surface + divider stroke).
struct CrashSurvivalCancelCard: View {
    @ObservedObject private var monitor = CrashMotionGuard.shared

    var body: some View {
        if monitor.isArmed {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "light.beacon.max.fill")
                        .font(.system(size: 15))
                        .foregroundColor(.redmedAccent)
                        .frame(width: 28, height: 28)
                        .background(Color.redmedAccent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Impact detected")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.redmedDark)
                        Text("Full brightness + locate-me siren are on. Local sensors only.")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.redmedMuted)
                    }
                }

                Button {
                    monitor.disarm()
                } label: {
                    Text("I'm OK — cancel alarm")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(red: 1, green: 0.447, blue: 0.537), .redmedAccent],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .clipShape(Capsule())
                        .shadow(color: Color.redmedAccent.opacity(0.28), radius: 7, y: 4)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.redmedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.redmedAccent.opacity(0.28), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.04), radius: 4, y: 2)
        }
    }
}

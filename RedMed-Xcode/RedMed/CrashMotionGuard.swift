import CoreMotion
import Foundation
import SwiftUI

/// On-device **vehicle crash / high-speed impact** guard (CoreMotion only).
/// Arms full brightness + locator siren.
/// Ignores running, walking, eating, sex/intimate motion, and hand/wrist handling.
/// Not Apple Crash Detection — no GPS/barometer fusion, no cloud.
@MainActor
final class CrashMotionGuard: ObservableObject {
    static let shared = CrashMotionGuard()

    @Published private(set) var isArmed = false

    /// Vehicle-level linear peak (g). Daily human motion stays well below this.
    private static let crashPeakG: Double = 16.0
    /// After true freefall, slightly lower peak still counts (ejection).
    private static let postFreefallPeakG: Double = 13.0
    /// Only this extreme peak can arm during recent human-activity / hand-busy windows.
    private static let overrideBusyPeakG: Double = 24.0
    /// Near-zero user accel = freefall / ballistic (longer than a hand dip).
    private static let freefallMaxG: Double = 0.20
    private static let freefallMinSeconds: TimeInterval = 0.22
    private static let freefallImpactWindow: TimeInterval = 0.40
    /// Broad human-activity band: walking, sex, eating gestures, phone handling.
    private static let humanActivityMinG: Double = 0.7
    private static let humanActivityMaxG: Double = 9.0
    private static let humanActivitySpikeCount: Int = 2
    private static let humanActivityWindow: TimeInterval = 8.0
    /// Recent hand/body busyness blocks arming unless override peak.
    private static let busyHoldSeconds: TimeInterval = 4.0
    /// Hand / wrist motion — moderate spin is enough (eating, gestures, intimacy).
    private static let handSpinRadPerSec: Double = 3.5
    private static let minJerkGPerSecond: Double = 120.0
    private static let sampleHz: Double = 50.0
    private static let cooldownSeconds: TimeInterval = 90

    private let manager = CMMotionManager()
    private var freefallSince: Date?
    private var freefallEndedAt: Date?
    private var lastMagnitude: Double = 0
    private var recentHumanPeaks: [Date] = []
    private var recentHandSpins: [Date] = []
    private var busyUntil: Date?
    private var lastArmAt: Date?
    private var isMonitoring = false

    private init() {}

    /// Start after first paint so cold launch stays light.
    func startMonitoring() {
        guard !isMonitoring else { return }
        guard manager.isDeviceMotionAvailable else { return }
        isMonitoring = true
        resetTransientState()
        manager.deviceMotionUpdateInterval = 1.0 / Self.sampleHz
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.evaluate(motion)
        }
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        manager.stopDeviceMotionUpdates()
        resetTransientState()
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
        resetTransientState()
        BrightnessBoost.beginSurvival()
        LocatorBeacon.beginSurvival()
    }

    private func resetTransientState() {
        freefallSince = nil
        freefallEndedAt = nil
        lastMagnitude = 0
        recentHumanPeaks.removeAll(keepingCapacity: true)
        recentHandSpins.removeAll(keepingCapacity: true)
        busyUntil = nil
    }

    private func markBusy(at now: Date) {
        let until = now.addingTimeInterval(Self.busyHoldSeconds)
        if let existing = busyUntil {
            busyUntil = max(existing, until)
        } else {
            busyUntil = until
        }
        freefallSince = nil
        freefallEndedAt = nil
    }

    private func evaluate(_ motion: CMDeviceMotion) {
        if isArmed { return }
        if let last = lastArmAt, Date().timeIntervalSince(last) < Self.cooldownSeconds {
            return
        }

        let accel = motion.userAcceleration
        let magnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
        let rot = motion.rotationRate
        let spin = sqrt(rot.x * rot.x + rot.y * rot.y + rot.z * rot.z)
        let dt = 1.0 / Self.sampleHz
        let jerk = abs(magnitude - lastMagnitude) / dt
        lastMagnitude = magnitude
        let now = Date()

        // Human activity band — sex, eating gestures, jogging, pocket bounce.
        if magnitude >= Self.humanActivityMinG && magnitude <= Self.humanActivityMaxG {
            recentHumanPeaks.append(now)
        }
        recentHumanPeaks.removeAll { now.timeIntervalSince($0) > Self.humanActivityWindow }
        if recentHumanPeaks.count >= Self.humanActivitySpikeCount {
            markBusy(at: now)
            return
        }

        // Hand / wrist motion (phone in hand, on wrist, gesture while eating).
        if spin >= Self.handSpinRadPerSec {
            recentHandSpins.append(now)
            recentHandSpins.removeAll { now.timeIntervalSince($0) > Self.humanActivityWindow }
            if magnitude < Self.overrideBusyPeakG {
                markBusy(at: now)
                return
            }
        } else {
            recentHandSpins.removeAll { now.timeIntervalSince($0) > Self.humanActivityWindow }
        }

        let isBusy = (busyUntil.map { now < $0 } ?? false)
            || !recentHandSpins.isEmpty
            || recentHumanPeaks.count >= Self.humanActivitySpikeCount

        // Freefall tracking — longer than a hand dip / body roll.
        if magnitude <= Self.freefallMaxG {
            if freefallSince == nil { freefallSince = now }
        } else if let since = freefallSince {
            if now.timeIntervalSince(since) >= Self.freefallMinSeconds {
                freefallEndedAt = now
            }
            freefallSince = nil
        }

        let inPostFreefallWindow: Bool = {
            guard let ended = freefallEndedAt else { return false }
            if now.timeIntervalSince(ended) > Self.freefallImpactWindow {
                freefallEndedAt = nil
                return false
            }
            return true
        }()

        guard jerk >= Self.minJerkGPerSecond else { return }

        // During recent sex / eating / hand motion, only an extreme smash can arm.
        let requiredPeak = isBusy ? Self.overrideBusyPeakG : Self.crashPeakG
        if magnitude >= requiredPeak {
            arm()
            return
        }

        if !isBusy, inPostFreefallWindow, magnitude >= Self.postFreefallPeakG {
            arm()
        }
    }
}

/// Cancel control on Aid — under panes, above the quote.
/// Sized like a full-width pane card; CTA matches open-pane topic rows.
struct CrashSurvivalCancelCard: View {
    @ObservedObject private var monitor = CrashMotionGuard.shared

    var body: some View {
        if monitor.isArmed {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "light.beacon.max.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(Color.redmedAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 11))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Crash / high-speed impact")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.redmedAccent)
                            .lineLimit(2)
                        Text("Siren + full brightness on — local sensors only")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.redmedMuted)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 0)
                }
                .padding(13)
                .frame(minHeight: 96, alignment: .top)

                Button {
                    monitor.disarm()
                } label: {
                    HStack {
                        Text("I'm OK — cancel alarm")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.redmedDark)
                        Spacer()
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.redmedAccent)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.redmedDivider, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
            }
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

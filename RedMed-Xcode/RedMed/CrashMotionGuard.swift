import CoreMotion
import Foundation
import SwiftUI

/// Shared crash thresholds — nonisolated so the off-main motion engine can read them.
/// Tuned to ignore walking, running, eating, phone handling, sex / masturbation,
/// and other rhythmic daily motion. Vehicle crash / high-speed impact only.
private enum CrashMotionThresholds {
    /// Vehicle-level linear peak (g). Daily human motion stays well below this.
    static let crashPeakG: Double = 16.0
    /// After true freefall, slightly lower peak still counts (ejection).
    static let postFreefallPeakG: Double = 13.0
    /// Only this extreme peak can arm during recent human-activity / hand-busy windows.
    static let overrideBusyPeakG: Double = 24.0
    /// Near-zero user accel = freefall / ballistic (longer than a hand dip).
    static let freefallMaxG: Double = 0.20
    static let freefallMinSeconds: TimeInterval = 0.22
    static let freefallImpactWindow: TimeInterval = 0.40
    /// Broad human-activity band: walking, sex, masturbation, eating, phone handling.
    static let humanActivityMinG: Double = 0.45
    static let humanActivityMaxG: Double = 10.0
    static let humanActivitySpikeCount: Int = 2
    static let humanActivityWindow: TimeInterval = 12.0
    /// How long a human/rhythm/hand busy lockout lasts (covers pauses in intimacy).
    static let busyHoldSeconds: TimeInterval = 14.0
    /// Hand / wrist rock — low enough to catch sex / masturbation / gestures.
    static let handSpinRadPerSec: Double = 2.0
    /// Repeating thrust / stroke cadence (seconds between human-band peaks).
    static let rhythmMinInterval: TimeInterval = 0.12
    static let rhythmMaxInterval: TimeInterval = 2.0
    static let rhythmHitCount: Int = 3
    /// Sustained human-band motion longer than this → busy (not a single bump).
    static let sustainedHumanSeconds: TimeInterval = 1.2
    static let minJerkGPerSecond: Double = 140.0
    static let sampleHz: Double = 50.0
    static let cooldownSeconds: TimeInterval = 90
}

/// Survival alarm arming: crash / severe impact (CoreMotion) or Find Help SOS
/// (owner + tapper / in-app scanner). Passerby `tapper.html` mirrors thresholds
/// via DeviceMotion. Arms full brightness + max system volume + locator siren.
/// Cancel on Aid or Stop SOS on Find Help.
/// Motion path ignores running, walking, eating, sex / masturbation / intimate
/// motion, rhythmic daily activity, and hand/wrist handling.
/// Not Apple Crash Detection — no GPS/barometer fusion, no cloud.
///
/// Motion samples run on a private serial queue (not the main thread) so Face ID /
/// Face ID / first tabs stay responsive. UI + brightness/volume/siren hop to main.
/// Arm/disarm uses a generation token so a late arm Task cannot restart the alarm
/// after Stop / disarm.
@MainActor
final class CrashMotionGuard: ObservableObject {
    static let shared = CrashMotionGuard()

    @Published private(set) var isArmed = false

    /// Off-main motion state + CoreMotion — never touches UIKit / @Published.
    private let engine = MotionEngine()

    private init() {}

    /// Start after first paint so cold launch stays light.
    func startMonitoring() {
        LocatorBeacon.warmAlarmCache()
        engine.startMonitoring { [weak self] generation in
            Task { @MainActor in
                self?.applyArm(generation: generation)
            }
        }
    }

    func stopMonitoring() {
        engine.stopMonitoring()
    }

    /// False-positive / SOS cancel — restores brightness/volume/siren holds.
    func disarm() {
        engine.invalidateArm()
        guard isArmed else { return }
        isArmed = false
        BrightnessBoost.endSurvival()
        VolumeBoost.endSurvival()
        LocatorBeacon.endSurvival()
    }

    /// Find Help SOS (owner + tapper) — same survival hold as crash
    /// (siren + max volume + full brightness).
    /// Claims the arm token on the calling MainActor — does not wait on the
    /// CoreMotion serial queue (that hop made the SOS button feel lagged).
    func armSOS() {
        let generation = engine.claimArmGeneration()
        applyArm(generation: generation)
    }

    private func applyArm(generation: UInt64) {
        // Drop stale arm Tasks invalidated by disarm / Stop the alarm.
        guard engine.isArmGenerationCurrent(generation) else { return }
        guard !isArmed else { return }
        isArmed = true
        // Paint Stop SOS / jump to 911 first — MPVolumeView + AVAudioSession hitch
        // the main thread if they run in the same turn as the button press.
        NotificationCenter.default.post(name: .redMedSurvivalArmed, object: nil)
        Task { @MainActor in
            guard self.engine.isArmGenerationCurrent(generation), self.isArmed else { return }
            BrightnessBoost.beginSurvival()
            VolumeBoost.beginSurvival()
            LocatorBeacon.beginSurvival()
        }
    }

    /// Serial CoreMotion evaluator — motion fields stay on `queue`; arm flag under `lock`.
    private final class MotionEngine: @unchecked Sendable {
        private let queue: OperationQueue = {
            let q = OperationQueue()
            q.name = "RedMed.CrashMotion"
            q.maxConcurrentOperationCount = 1
            q.qualityOfService = .userInitiated
            return q
        }()
        private let lock = NSLock()

        private var manager: CMMotionManager?
        private var isMonitoring = false
        private var motionArmed = false
        private var armGeneration: UInt64 = 0
        private var freefallSince: Date?
        private var freefallEndedAt: Date?
        private var lastMagnitude: Double = 0
        private var recentHumanPeaks: [Date] = []
        private var recentHandSpins: [Date] = []
        private var humanBurstStart: Date?
        private var busyUntil: Date?
        private var lastArmAt: Date?
        private var onArm: ((UInt64) -> Void)?

        func startMonitoring(onArm: @escaping (UInt64) -> Void) {
            queue.addOperation { [weak self] in
                guard let self else { return }
                self.onArm = onArm
                guard !self.isMonitoring else { return }
                let motion = self.manager ?? CMMotionManager()
                self.manager = motion
                guard motion.isDeviceMotionAvailable else { return }
                self.isMonitoring = true
                self.resetTransientState()
                motion.deviceMotionUpdateInterval = 1.0 / CrashMotionThresholds.sampleHz
                motion.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: self.queue) { [weak self] sample, _ in
                    guard let self, let sample else { return }
                    self.evaluate(sample)
                }
            }
        }

        func stopMonitoring() {
            queue.addOperation { [weak self] in
                guard let self else { return }
                guard self.isMonitoring else { return }
                self.isMonitoring = false
                self.manager?.stopDeviceMotionUpdates()
                self.resetTransientState()
            }
        }

        func invalidateArm() {
            lock.lock()
            armGeneration &+= 1
            motionArmed = false
            lock.unlock()
            queue.addOperation { [weak self] in
                self?.resetTransientState()
            }
        }

        func requestArm(onArm: @escaping (UInt64) -> Void) {
            queue.addOperation { [weak self] in
                guard let self else { return }
                self.onArm = onArm
                self.armNow()
            }
        }

        /// Explicit SOS — claim generation on the caller (MainActor) without
        /// waiting for the motion queue. Crash path still uses `requestArm`.
        func claimArmGeneration() -> UInt64 {
            lock.lock()
            defer { lock.unlock() }
            if motionArmed {
                return armGeneration
            }
            motionArmed = true
            armGeneration &+= 1
            return armGeneration
        }

        /// Non-blocking — safe to call from MainActor.
        func isArmGenerationCurrent(_ generation: UInt64) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            return motionArmed && armGeneration == generation
        }

        private func armNow() {
            let generation: UInt64
            lock.lock()
            if motionArmed {
                lock.unlock()
                return
            }
            motionArmed = true
            armGeneration &+= 1
            generation = armGeneration
            lastArmAt = Date()
            lock.unlock()

            freefallSince = nil
            freefallEndedAt = nil
            lastMagnitude = 0
            recentHumanPeaks.removeAll(keepingCapacity: true)
            recentHandSpins.removeAll(keepingCapacity: true)
            humanBurstStart = nil
            busyUntil = nil
            onArm?(generation)
        }

        private func resetTransientState() {
            freefallSince = nil
            freefallEndedAt = nil
            lastMagnitude = 0
            recentHumanPeaks.removeAll(keepingCapacity: true)
            recentHandSpins.removeAll(keepingCapacity: true)
            humanBurstStart = nil
            busyUntil = nil
        }

        private func markBusy(at now: Date) {
            let until = now.addingTimeInterval(CrashMotionThresholds.busyHoldSeconds)
            if let existing = busyUntil {
                busyUntil = max(existing, until)
            } else {
                busyUntil = until
            }
            freefallSince = nil
            freefallEndedAt = nil
            humanBurstStart = nil
        }

        /// Sex / masturbation / jogging / similar — repeating human-band peaks.
        private func isRhythmicHumanActivity(now: Date) -> Bool {
            let peaks = recentHumanPeaks.filter {
                now.timeIntervalSince($0) <= CrashMotionThresholds.humanActivityWindow
            }
            guard peaks.count >= CrashMotionThresholds.rhythmHitCount + 1 else { return false }
            var hits = 0
            for i in 1..<peaks.count {
                let dt = peaks[i].timeIntervalSince(peaks[i - 1])
                if dt >= CrashMotionThresholds.rhythmMinInterval
                    && dt <= CrashMotionThresholds.rhythmMaxInterval {
                    hits += 1
                    if hits >= CrashMotionThresholds.rhythmHitCount { return true }
                }
            }
            return false
        }

        private func evaluate(_ motion: CMDeviceMotion) {
            lock.lock()
            let alreadyArmed = motionArmed
            let lastArm = lastArmAt
            lock.unlock()
            if alreadyArmed { return }
            if let last = lastArm, Date().timeIntervalSince(last) < CrashMotionThresholds.cooldownSeconds {
                return
            }

            let accel = motion.userAcceleration
            let magnitude = sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
            let rot = motion.rotationRate
            let spin = sqrt(rot.x * rot.x + rot.y * rot.y + rot.z * rot.z)
            let dt = 1.0 / CrashMotionThresholds.sampleHz
            let jerk = abs(magnitude - lastMagnitude) / dt
            lastMagnitude = magnitude
            let now = Date()

            if magnitude >= CrashMotionThresholds.humanActivityMinG && magnitude <= CrashMotionThresholds.humanActivityMaxG {
                recentHumanPeaks.append(now)
                if humanBurstStart == nil { humanBurstStart = now }
            } else if let start = humanBurstStart,
                      now.timeIntervalSince(start) > CrashMotionThresholds.humanActivityWindow {
                humanBurstStart = nil
            }
            recentHumanPeaks.removeAll { now.timeIntervalSince($0) > CrashMotionThresholds.humanActivityWindow }

            // Sustained human-band motion (sex, masturbation, jogging phone bounce).
            if let start = humanBurstStart,
               now.timeIntervalSince(start) >= CrashMotionThresholds.sustainedHumanSeconds,
               !recentHumanPeaks.isEmpty {
                markBusy(at: now)
                return
            }

            // Rhythmic cadence — repeating thrust / stroke / step intervals.
            if isRhythmicHumanActivity(now: now) {
                markBusy(at: now)
                return
            }

            if recentHumanPeaks.count >= CrashMotionThresholds.humanActivitySpikeCount {
                markBusy(at: now)
                return
            }

            if spin >= CrashMotionThresholds.handSpinRadPerSec {
                recentHandSpins.append(now)
                recentHandSpins.removeAll { now.timeIntervalSince($0) > CrashMotionThresholds.humanActivityWindow }
                if magnitude < CrashMotionThresholds.overrideBusyPeakG {
                    markBusy(at: now)
                    return
                }
            } else {
                recentHandSpins.removeAll { now.timeIntervalSince($0) > CrashMotionThresholds.humanActivityWindow }
            }

            let isBusy = (busyUntil.map { now < $0 } ?? false)
                || !recentHandSpins.isEmpty
                || recentHumanPeaks.count >= CrashMotionThresholds.humanActivitySpikeCount
                || isRhythmicHumanActivity(now: now)

            if magnitude <= CrashMotionThresholds.freefallMaxG {
                if freefallSince == nil { freefallSince = now }
            } else if let since = freefallSince {
                if now.timeIntervalSince(since) >= CrashMotionThresholds.freefallMinSeconds {
                    freefallEndedAt = now
                }
                freefallSince = nil
            }

            let inPostFreefallWindow: Bool = {
                guard let ended = freefallEndedAt else { return false }
                if now.timeIntervalSince(ended) > CrashMotionThresholds.freefallImpactWindow {
                    freefallEndedAt = nil
                    return false
                }
                return true
            }()

            guard jerk >= CrashMotionThresholds.minJerkGPerSecond else { return }

            let requiredPeak = isBusy ? CrashMotionThresholds.overrideBusyPeakG : CrashMotionThresholds.crashPeakG
            if magnitude >= requiredPeak {
                armNow()
                return
            }

            if !isBusy, inPostFreefallWindow, magnitude >= CrashMotionThresholds.postFreefallPeakG {
                armNow()
            }
        }
    }
}

/// Cancel on Aid — under the pane grid (above owner quiet prayer when present).
/// Outside LazyVGrid so pane expand/collapse is undisturbed.
struct CrashSurvivalCancelCard: View {
    @ObservedObject private var monitor = CrashMotionGuard.shared

    var body: some View {
        if monitor.isArmed {
            Button {
                RedMedHaptics.medium()
                withAnimation(RedMedMotion.snappy) {
                    monitor.disarm()
                }
            } label: {
                HStack {
                    Text("Stop the alarm")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.redmedDark)
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.redmedAccent)
                        .symbolEffect(.bounce, value: monitor.isArmed)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.redmedBg)
                .clipShape(RoundedRectangle(cornerRadius: RedMedChrome.boxRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: RedMedChrome.boxRadius)
                        .strokeBorder(Color.redmedDivider, lineWidth: 1)
                )
            }
            .buttonStyle(RedMedPressStyle(haptic: nil))
            .padding(.top, 5)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }
}

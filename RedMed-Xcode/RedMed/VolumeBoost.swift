import AVFoundation
import MediaPlayer
import UIKit

/// Forces system media volume to 100% for the survival alarm (crash / severe impact or SOS).
/// Saves the prior level and restores it when the hold is cancelled.
/// Uses `MPVolumeView`'s hidden slider — `AVAudioSession.outputVolume` is read-only.
/// Simulator: slider writes are often no-ops for hardware volume.
@MainActor
enum VolumeBoost {
    private static var savedVolume: Float?
    private static var survivalHold = false
    private static var volumeView: MPVolumeView?
    private static var volumeSlider: UISlider?
    private static var volumeObservation: NSKeyValueObservation?
    private static var foregroundObserver: NSObjectProtocol?
    private static var activeObserver: NSObjectProtocol?
    /// Ignore KVO echoes from our own slider writes.
    private static var suppressingObservation = false

    /// Survival arm — keeps max volume even while backgrounded.
    static func beginSurvival() {
        if !survivalHold {
            savedVolume = AVAudioSession.sharedInstance().outputVolume
            survivalHold = true
            installVolumeControls()
            installLifecycleObservers()
            installVolumeObservation()
        }
        applyBoost()
    }

    static func endSurvival() {
        guard survivalHold else { return }
        survivalHold = false
        removeVolumeObservation()
        removeLifecycleObservers()
        if let savedVolume {
            setSystemVolume(savedVolume)
        }
        savedVolume = nil
        // Tear down after the restore write has a chance to land.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard !survivalHold else { return }
            tearDownVolumeControls()
        }
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

    private static func installVolumeObservation() {
        removeVolumeObservation()
        volumeObservation = AVAudioSession.sharedInstance().observe(
            \.outputVolume,
            options: [.new]
        ) { _, change in
            Task { @MainActor in
                guard survivalHold, !suppressingObservation else { return }
                guard let value = change.newValue, value < 0.99 else { return }
                applyBoost()
            }
        }
    }

    private static func removeVolumeObservation() {
        volumeObservation?.invalidate()
        volumeObservation = nil
    }

    private static func installVolumeControls() {
        if volumeView != nil, volumeSlider != nil { return }
        tearDownVolumeControls()

        let view = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 1, height: 1))
        view.alpha = 0.01
        view.isUserInteractionEnabled = false
        volumeView = view

        if let window = keyWindow() {
            window.addSubview(view)
        }

        volumeSlider = view.subviews.compactMap { $0 as? UISlider }.first
        if volumeSlider == nil {
            // Hierarchy may not be ready on first layout pass.
            DispatchQueue.main.async {
                guard survivalHold else { return }
                volumeSlider = volumeView?.subviews.compactMap { $0 as? UISlider }.first
                applyBoost()
            }
        }
    }

    private static func tearDownVolumeControls() {
        volumeView?.removeFromSuperview()
        volumeView = nil
        volumeSlider = nil
    }

    private static func applyBoost() {
        setSystemVolume(1.0)
    }

    private static func setSystemVolume(_ value: Float) {
        let clamped = max(0, min(1, value))
        installVolumeControls()
        guard let slider = volumeSlider else { return }

        suppressingObservation = true
        // Immediate write when the slider is already wired; retry catches
        // the common first-frame miss after MPVolumeView attach.
        slider.value = clamped
        DispatchQueue.main.async {
            slider.value = clamped
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                slider.value = clamped
                suppressingObservation = false
            }
        }
    }

    private static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
            ?? UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap(\.windows)
                .first
    }
}

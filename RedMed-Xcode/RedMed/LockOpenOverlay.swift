import AVFoundation
import SwiftUI
import UIKit

/// Bundled Face ID → Main open clip. Muted. Does not touch `AVAudioSession`
/// (survival alarm owns that). Missing file is a no-op.
enum LockOpenClip {
    static let resourceName = "LockOpen"

    static var url: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: "mp4")
    }

    /// Kept alive so unlock playback reuses a decoded asset.
    private static var prewarmedAsset: AVURLAsset?

    static var asset: AVURLAsset? {
        if let prewarmedAsset { return prewarmedAsset }
        guard let url else { return nil }
        return AVURLAsset(url: url)
    }

    /// Decode keys only while the app is active. Creating AVURLAsset under a
    /// Face ID sheet (scene `.inactive`) trips FigApplicationStateMonitor
    /// AllocFailed in CoreMedia.
    static func prewarm() {
        guard UIApplication.shared.applicationState == .active else { return }
        guard let url else { return }
        if prewarmedAsset != nil { return }
        let asset = AVURLAsset(url: url)
        prewarmedAsset = asset
        Task { @MainActor in
            _ = try? await asset.load(.isPlayable, .duration)
        }
    }
}

/// Full-bleed overlay. Plays once, then calls `onFinished`.
struct LockOpenOverlay: UIViewRepresentable {
    var onFinished: () -> Void

    func makeUIView(context: Context) -> LockOpenPlayerView {
        let view = LockOpenPlayerView()
        view.onFinished = onFinished
        view.start()
        return view
    }

    func updateUIView(_ uiView: LockOpenPlayerView, context: Context) {}

    static func dismantleUIView(_ uiView: LockOpenPlayerView, coordinator: ()) {
        uiView.stop()
    }
}

final class LockOpenPlayerView: UIView {
    var onFinished: (() -> Void)?

    private var player: AVPlayer?
    private var endObserver: NSObjectProtocol?
    private var failObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?
    private var didFinish = false

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    private static let cream = UIColor(
        red: 1, green: 0.969, blue: 0.969, alpha: 1
    )

    func start() {
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = Self.cream.cgColor
        // Cover Main immediately; delay AVPlayer until active so CoreMedia does
        // not AllocFail its process-state monitor under a dismissing Face ID sheet.
        if UIApplication.shared.applicationState == .active {
            startPlayback()
        } else {
            activeObserver = NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.clearActiveObserver()
                self?.startPlayback()
            }
        }
    }

    private func startPlayback() {
        guard !didFinish, player == nil else { return }
        guard let asset = LockOpenClip.asset else {
            finish()
            return
        }
        let item = AVPlayerItem(asset: asset)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause
        self.player = player
        playerLayer.player = player
        let queue = OperationQueue.main
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: queue
        ) { [weak self] _ in
            self?.finish()
        }
        failObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: queue
        ) { [weak self] _ in
            self?.finish()
        }
        player.play()
    }

    func stop() {
        clearActiveObserver()
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        if let failObserver {
            NotificationCenter.default.removeObserver(failObserver)
            self.failObserver = nil
        }
        player?.pause()
        player = nil
        playerLayer.player = nil
    }

    private func clearActiveObserver() {
        if let activeObserver {
            NotificationCenter.default.removeObserver(activeObserver)
            self.activeObserver = nil
        }
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        stop()
        onFinished?()
    }
}

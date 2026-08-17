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

    /// Kept alive across Face ID so unlock playback reuses a decoded asset.
    private static var prewarmedAsset: AVURLAsset?

    static var asset: AVURLAsset? {
        if let prewarmedAsset { return prewarmedAsset }
        guard let url else { return nil }
        return AVURLAsset(url: url)
    }

    /// Decode keys while Face ID is up so the first success frame is not a stall.
    static func prewarm() {
        guard let url else { return }
        let asset = AVURLAsset(url: url)
        prewarmedAsset = asset
        Task {
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
    private var didFinish = false

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    func start() {
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
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.backgroundColor = UIColor(
            red: 1, green: 0.969, blue: 0.969, alpha: 1
        ).cgColor
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

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        stop()
        onFinished?()
    }
}

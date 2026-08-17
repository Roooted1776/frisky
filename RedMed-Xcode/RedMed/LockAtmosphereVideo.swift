import AVFoundation
import SwiftUI
import UIKit

/// Bundled lock-open clip. Muted atmosphere behind the glyph — never a gate.
/// Face ID and Main never wait on this player (no ready-to-play, no overlay,
/// no end callback). Does not touch `AVAudioSession`. Missing file / Reduce
/// Motion / Low Power leave the cream fallback.
enum LockOpenClip {
    static let resourceName = "LockOpen"

    static var url: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: "mp4")
    }

    static var shouldPlay: Bool {
        !UIAccessibility.isReduceMotionEnabled
            && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }
}

/// Full-bleed muted open clip as lock-shell background. Plays once and holds
/// the last (cream) frame. Unlock tears it down without waiting.
struct LockAtmosphereVideo: UIViewRepresentable {
    /// Pause on true background only — Face ID holds `.inactive` and must keep playing.
    var playing: Bool

    func makeUIView(context: Context) -> LockAtmospherePlayerView {
        let view = LockAtmospherePlayerView()
        view.playing = playing
        view.schedulePrepare()
        return view
    }

    func updateUIView(_ uiView: LockAtmospherePlayerView, context: Context) {
        uiView.playing = playing
    }

    static func dismantleUIView(_ uiView: LockAtmospherePlayerView, coordinator: ()) {
        uiView.stop()
    }
}

final class LockAtmospherePlayerView: UIView {
    var playing = true {
        didSet { applyPlaying() }
    }

    private var player: AVPlayer?
    private var dead = false
    private var ended = false
    private var prepareStarted = false

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        // Cream first paint — never a black/white AV hole while the item loads.
        let cream = UIColor(red: 1, green: 0.969, blue: 0.969, alpha: 1)
        backgroundColor = cream
        playerLayer.backgroundColor = cream.cgColor
        playerLayer.videoGravity = .resizeAspectFill
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// Off this turn so Face ID `onAppear` is not paying AVPlayer setup.
    func schedulePrepare() {
        guard !prepareStarted else { return }
        prepareStarted = true
        guard LockOpenClip.shouldPlay, let url = LockOpenClip.url else { return }
        DispatchQueue.main.async { [weak self] in
            self?.attach(url)
        }
    }

    func stop() {
        dead = true
        // Pause this turn so unlock → Main is not decoding; release after paint.
        player?.pause()
        playerLayer.player = nil
        let dying = player
        player = nil
        NotificationCenter.default.removeObserver(self)
        DispatchQueue.main.async {
            dying?.replaceCurrentItem(with: nil)
        }
    }

    private func attach(_ url: URL) {
        guard !dead, player == nil else { return }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause
        player.automaticallyWaitsToMinimizeStalling = false
        player.preventsDisplaySleepDuringVideoPlayback = false
        self.player = player
        playerLayer.player = player
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itemDidEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        applyPlaying()
    }

    private func applyPlaying() {
        guard let player, !dead else { return }
        if playing, !ended, LockOpenClip.shouldPlay {
            player.play()
        } else {
            player.pause()
        }
    }

    @objc private func itemDidEnd() {
        ended = true
        player?.pause()
    }
}

/// Higgs Face ID–frame clip. Muted square mark under Face ID / Face page —
/// never a gate. Missing file / Reduce Motion / Low Power: LockEntryPage is
/// cream only; Face page falls back to `LockMedGlyph`. Not Apple Face ID scan rings.
enum FaceIDFrameClip {
    static let resourceName = "FaceIDFrame"

    static var url: URL? {
        Bundle.main.url(forResource: resourceName, withExtension: "mp4")
    }

    static var shouldPlay: Bool {
        LockOpenClip.shouldPlay && url != nil
    }
}

/// Face ID–sized square clip (cream + red medical circle). Plays once and
/// holds the last frame. Unlock tears it down without waiting.
struct FaceIDFrameVideo: UIViewRepresentable {
    var playing: Bool

    func makeUIView(context: Context) -> FaceIDFramePlayerView {
        let view = FaceIDFramePlayerView()
        view.playing = playing
        view.schedulePrepare()
        return view
    }

    func updateUIView(_ uiView: FaceIDFramePlayerView, context: Context) {
        uiView.playing = playing
    }

    static func dismantleUIView(_ uiView: FaceIDFramePlayerView, coordinator: ()) {
        uiView.stop()
    }
}

final class FaceIDFramePlayerView: UIView {
    var playing = true {
        didSet { applyPlaying() }
    }

    private var player: AVPlayer?
    private var dead = false
    private var ended = false
    private var prepareStarted = false

    override class var layerClass: AnyClass { AVPlayerLayer.self }

    private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        let cream = UIColor(red: 1, green: 0.969, blue: 0.969, alpha: 1)
        backgroundColor = cream
        playerLayer.backgroundColor = cream.cgColor
        // Aspect so cream margin stays — do not crop the circle.
        playerLayer.videoGravity = .resizeAspect
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func schedulePrepare() {
        guard !prepareStarted else { return }
        prepareStarted = true
        guard FaceIDFrameClip.shouldPlay, let url = FaceIDFrameClip.url else { return }
        DispatchQueue.main.async { [weak self] in
            self?.attach(url)
        }
    }

    func stop() {
        dead = true
        player?.pause()
        playerLayer.player = nil
        let dying = player
        player = nil
        NotificationCenter.default.removeObserver(self)
        DispatchQueue.main.async {
            dying?.replaceCurrentItem(with: nil)
        }
    }

    private func attach(_ url: URL) {
        guard !dead, player == nil else { return }
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        player.isMuted = true
        player.actionAtItemEnd = .pause
        player.automaticallyWaitsToMinimizeStalling = false
        player.preventsDisplaySleepDuringVideoPlayback = false
        self.player = player
        playerLayer.player = player
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(itemDidEnd),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )
        applyPlaying()
    }

    private func applyPlaying() {
        guard let player, !dead else { return }
        if playing, !ended, FaceIDFrameClip.shouldPlay {
            player.play()
        } else {
            player.pause()
        }
    }

    @objc private func itemDidEnd() {
        ended = true
        player?.pause()
    }
}

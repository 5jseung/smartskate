import AVFoundation

/// Plays a recorded session and rebuilds the music from the log, so you hear what you heard on the ice.
final class SyncedPlayer: ObservableObject {
    let player: AVPlayer
    @Published private(set) var currentTime: Double = 0

    /// Bluetooth headphone delay in seconds. 0 until we calibrate it.
    var audioDelay: Double = 0

    private let session: Session
    private var audio: AVAudioPlayer?
    private var observer: Any?
    private var range: ClosedRange<Double>?
    private var loop = false
    private var onEnd: (() -> Void)?
    private var seeking = false

    init(session: Session, song: Song?, withMusic: Bool = true) {
        self.session = session
        player = AVPlayer(url: Store.videoURL(session))
        if withMusic, let song {
            audio = try? AVAudioPlayer(contentsOf: Store.songURL(song))
            audio?.prepareToPlay()
        }
        MusicEngine.configureAudioSession()
        observer = player.addPeriodicTimeObserver(forInterval: CMTime(value: 1, timescale: 20), queue: .main) { [weak self] t in
            self?.tick(t.seconds)
        }
    }

    deinit {
        if let observer { player.removeTimeObserver(observer) }
        audio?.stop()
    }

    func seek(_ t: Double) {
        seeking = true
        player.seek(to: CMTime(seconds: t, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            DispatchQueue.main.async { self?.seeking = false }
        }
    }

    func pause() {
        player.pause()
        audio?.pause()
    }

    /// Play just one part of the video. loop = repeat it; otherwise onEnd is called when it finishes.
    func play(range r: ClosedRange<Double>, loop: Bool, rate: Float = 1, onEnd: (() -> Void)? = nil) {
        range = r
        self.loop = loop
        self.onEnd = onEnd
        seek(r.lowerBound)
        player.rate = rate
    }

    func clearRange() {
        range = nil
        onEnd = nil
    }

    func setRate(_ rate: Float) {
        player.rate = rate
    }

    private func tick(_ t: Double) {
        currentTime = t
        guard !seeking else { return }
        if let r = range, t >= r.upperBound {
            if loop {
                seek(r.lowerBound)
            } else {
                let done = onEnd
                clearRange()
                pause()
                done?()
            }
            return
        }
        syncAudio(t)
    }

    // Music only plays at normal speed. In slow motion it's off.
    private func syncAudio(_ t: Double) {
        guard let audio else { return }
        guard player.rate == 1,
              let state = session.musicState(at: t - audioDelay),
              state.playing,
              state.songTime < audio.duration else {
            if audio.isPlaying { audio.pause() }
            return
        }
        if !audio.isPlaying || abs(audio.currentTime - state.songTime) > 0.15 {
            audio.currentTime = state.songTime
        }
        if !audio.isPlaying { audio.play() }
    }
}

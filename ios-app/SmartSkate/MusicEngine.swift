import AVFoundation

/// Plays the practice music and, while recording, logs every change against the video clock.
final class MusicEngine: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentSection: MusicSection?

    var videoClock: () -> Double? = { nil }
    private(set) var events: [MusicEvent] = []
    private var logging = false
    private var player: AVAudioPlayer?

    static func configureAudioSession() {
        let s = AVAudioSession.sharedInstance()
        try? s.setCategory(.playback, mode: .default)
        try? s.setActive(true)
    }

    var position: Double { player?.currentTime ?? 0 }
    var duration: Double { player?.duration ?? 0 }

    func load(_ song: Song) {
        MusicEngine.configureAudioSession()
        player?.stop()
        player = try? AVAudioPlayer(contentsOf: Store.songURL(song))
        player?.delegate = self
        player?.prepareToPlay()
        isPlaying = false
        currentSection = nil
    }

    func unload() {
        player?.stop()
        player = nil
        isPlaying = false
        currentSection = nil
    }

    func togglePlay() { isPlaying ? pause() : resume() }

    func resume() {
        guard let p = player else { return }
        p.play()
        isPlaying = true
        log("Play")
    }

    func pause() {
        guard let p = player else { return }
        p.pause()
        isPlaying = false
        log("Pause")
    }

    func playSection(_ s: MusicSection) {
        guard let p = player else { return }
        p.currentTime = s.start
        p.play()
        isPlaying = true
        currentSection = s
        log("Section \(s.name)")
    }

    func repeatSection() {
        if let s = currentSection {
            playSection(s)
        } else if let p = player {
            p.currentTime = 0
            p.play()
            isPlaying = true
            log("Restart")
        }
    }

    func seek(to t: Double) {
        player?.currentTime = t
        log("Seek")
    }

    func stopPlayback() {
        player?.stop()
        isPlaying = false
    }

    func startLog() {
        events = []
        logging = true
        log("Recording started")
    }

    func endLog() -> [MusicEvent] {
        log("Recording stopped")
        logging = false
        return events
    }

    private func log(_ note: String) {
        guard logging else { return }
        events.append(MusicEvent(videoTime: videoClock() ?? 0,
                                 songTime: player?.currentTime ?? 0,
                                 playing: isPlaying,
                                 note: note))
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.log("Song ended")
        }
    }
}

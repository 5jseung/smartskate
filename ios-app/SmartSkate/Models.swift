import Foundation

enum AttemptResult: String, Codable, CaseIterable, Identifiable {
    case clean, fell, unsure
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct MusicSection: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var start: Double
}

struct Song: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var fileName: String
    var sections: [MusicSection] = []
}

/// One line in the music log. videoTime = seconds since the first recorded frame.
struct MusicEvent: Codable, Hashable {
    var videoTime: Double
    var songTime: Double
    var playing: Bool
    var note: String
}

enum MomentSource: String, Codable {
    case manual, auto, wrist
}

struct Moment: Codable, Identifiable, Hashable {
    var id = UUID()
    var time: Double
    var start: Double
    var end: Double
    var source: MomentSource
    var label: String?
    var result: AttemptResult?
}

struct Session: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var songID: UUID?
    var videoFileName: String
    var duration: Double = 0
    var events: [MusicEvent] = []
    var moments: [Moment] = []
}

struct MusicState {
    var songTime: Double
    var playing: Bool
}

extension Session {
    /// Which part of the song was playing at a given point in the video.
    func musicState(at t: Double) -> MusicState? {
        guard let last = events.last(where: { $0.videoTime <= t }) else { return nil }
        if last.playing {
            return MusicState(songTime: last.songTime + (t - last.videoTime), playing: true)
        }
        return MusicState(songTime: last.songTime, playing: false)
    }
}

func formatTime(_ seconds: Double) -> String {
    let t = max(0, Int(seconds.rounded(.down)))
    return String(format: "%d:%02d", t / 60, t % 60)
}

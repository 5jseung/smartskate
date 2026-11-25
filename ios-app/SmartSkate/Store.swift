import Foundation

/// Saves songs and sessions as JSON in the app's Documents folder.
final class Store: ObservableObject {
    @Published var songs: [Song] = []
    @Published var sessions: [Session] = []

    static let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    static let musicDir = docs.appendingPathComponent("Music", isDirectory: true)
    static let videoDir = docs.appendingPathComponent("Videos", isDirectory: true)
    private let songsURL = docs.appendingPathComponent("songs.json")
    private let sessionsURL = docs.appendingPathComponent("sessions.json")

    init() {
        for dir in [Store.musicDir, Store.videoDir] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        songs = load(songsURL) ?? []
        sessions = load(sessionsURL) ?? []
    }

    // MARK: Files

    private func load<T: Decodable>(_ url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func songURL(_ song: Song) -> URL { musicDir.appendingPathComponent(song.fileName) }
    static func videoURL(_ session: Session) -> URL { videoDir.appendingPathComponent(session.videoFileName) }

    // MARK: Songs

    func song(_ id: UUID?) -> Song? { songs.first { $0.id == id } }

    @discardableResult
    func importSong(from url: URL) throws -> Song {
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let fileName = UUID().uuidString + "." + url.pathExtension
        try FileManager.default.copyItem(at: url, to: Store.musicDir.appendingPathComponent(fileName))
        let song = Song(title: url.deletingPathExtension().lastPathComponent, fileName: fileName)
        songs.append(song)
        write(songs, to: songsURL)
        return song
    }

    func updateSong(_ song: Song) {
        guard let i = songs.firstIndex(where: { $0.id == song.id }) else { return }
        songs[i] = song
        write(songs, to: songsURL)
    }

    func deleteSong(_ song: Song) {
        try? FileManager.default.removeItem(at: Store.songURL(song))
        songs.removeAll { $0.id == song.id }
        write(songs, to: songsURL)
    }

    // MARK: Sessions

    func session(_ id: UUID) -> Session? { sessions.first { $0.id == id } }

    func update(_ session: Session) {
        if let i = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[i] = session
        } else {
            sessions.append(session)
        }
        write(sessions, to: sessionsURL)
    }

    func deleteSession(_ session: Session) {
        try? FileManager.default.removeItem(at: Store.videoURL(session))
        sessions.removeAll { $0.id == session.id }
        write(sessions, to: sessionsURL)
    }
}

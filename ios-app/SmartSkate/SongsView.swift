import SwiftUI
import UniformTypeIdentifiers

struct SongsView: View {
    @EnvironmentObject var store: Store
    @State private var importing = false
    @State private var error: String?

    var body: some View {
        List {
            if store.songs.isEmpty {
                Text("Add your program music (MP3 or WAV from the Files app).")
                    .foregroundStyle(.secondary)
            }
            ForEach(store.songs) { song in
                NavigationLink(value: Route.song(song.id)) {
                    VStack(alignment: .leading) {
                        Text(song.title)
                        Text("\(song.sections.count) sections").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                offsets.map { store.songs[$0] }.forEach(store.deleteSong)
            }
        }
        .toolbar {
            Button { importing = true } label: { Label("Add song", systemImage: "plus") }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            do {
                try store.importSong(from: result.get())
            } catch {
                self.error = error.localizedDescription
            }
        }
        .alert("Couldn't add the song", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK") {}
        } message: {
            Text(error ?? "")
        }
        .navigationTitle("Songs")
    }
}

/// Play the song and drop section markers (A, B, C...) where the wrist buttons should jump to.
struct SongEditorView: View {
    @EnvironmentObject var store: Store
    let songID: UUID
    @StateObject private var music = MusicEngine()
    @State private var position: Double = 0
    @State private var dragging = false
    private let timer = Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()

    private var song: Song? { store.song(songID) }

    var body: some View {
        List {
            if let song {
                Section {
                    TextField("Title", text: Binding(get: { song.title }, set: { newTitle in
                        var s = song
                        s.title = newTitle
                        store.updateSong(s)
                    }))
                    HStack {
                        Button { music.togglePlay() } label: {
                            Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(.bordered)
                        Text(formatTime(position)).monospacedDigit()
                        Slider(value: $position, in: 0...max(music.duration, 1), onEditingChanged: { editing in
                            dragging = editing
                            if !editing { music.seek(to: position) }
                        })
                        Text(formatTime(music.duration)).monospacedDigit()
                    }
                    Button { addSection() } label: {
                        Label("Add section here", systemImage: "plus")
                    }
                } footer: {
                    Text("Play the song and tap Add section at each point you want to jump to while skating.")
                }

                Section("Sections") {
                    let sections = song.sections.sorted { $0.start < $1.start }
                    ForEach(sections) { s in
                        Button { music.playSection(s) } label: {
                            HStack {
                                Text(s.name).bold()
                                Spacer()
                                Text(formatTime(s.start)).monospacedDigit().foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { sections[$0].id }
                        var updated = song
                        updated.sections.removeAll { ids.contains($0.id) }
                        store.updateSong(updated)
                    }
                }
            }
        }
        .navigationTitle("Song")
        .onAppear { if let song { music.load(song) } }
        .onReceive(timer) { _ in if !dragging { position = music.position } }
        .onDisappear { music.stopPlayback() }
    }

    private func addSection() {
        guard var s = song else { return }
        let used = Set(s.sections.map(\.name))
        let name = (65...90).map { String(Character(UnicodeScalar(UInt8($0)))) }.first { !used.contains($0) } ?? "\(s.sections.count + 1)"
        s.sections.append(MusicSection(name: name, start: music.position))
        store.updateSong(s)
    }
}

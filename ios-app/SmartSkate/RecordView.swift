import SwiftUI

/// Camera preview + music buttons + Mark. One continuous recording from Record to Stop.
struct RecordView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router
    @StateObject private var camera = CameraRecorder()
    @StateObject private var music = MusicEngine()

    @State private var songID: UUID?
    @State private var draft: Session?
    @State private var marks: [Moment] = []
    @State private var elapsed: Double = 0
    @State private var saving = false
    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var song: Song? { store.song(songID) }

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                CameraPreview(session: camera.session)
                if camera.isRecording {
                    Label(formatTime(elapsed), systemImage: "circle.fill")
                        .foregroundStyle(.red)
                        .padding(8)
                        .background(.black.opacity(0.6), in: Capsule())
                        .padding()
                }
                if let e = camera.error {
                    Text(e).foregroundStyle(.white).padding().background(.red).padding()
                }
            }
            controls.frame(width: 260)
        }
        .navigationBarBackButtonHidden(camera.isRecording || saving)
        .task {
            await camera.configure()
            let cam = camera
            music.videoClock = { cam.currentVideoTime() }
            if songID == nil {
                songID = store.songs.first?.id
                loadSong()
            }
        }
        .onChange(of: songID) { loadSong() }
        .onReceive(timer) { _ in
            if camera.isRecording { elapsed = camera.currentVideoTime() ?? 0 }
        }
        .onDisappear {
            music.stopPlayback()
            camera.shutdown()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private var controls: some View {
        ScrollView {
            VStack(spacing: 12) {
                Picker("Music", selection: $songID) {
                    Text("No music").tag(UUID?.none)
                    ForEach(store.songs) { s in
                        Text(s.title).tag(Optional(s.id))
                    }
                }
                .pickerStyle(.menu)
                .disabled(camera.isRecording)

                if let song {
                    HStack {
                        Button { music.togglePlay() } label: {
                            Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        Button { music.repeatSection() } label: {
                            Image(systemName: "gobackward")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .buttonStyle(.bordered)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 56))]) {
                        ForEach(song.sections.sorted { $0.start < $1.start }) { s in
                            Button(s.name) { music.playSection(s) }
                                .frame(minHeight: 44)
                                .buttonStyle(.bordered)
                                .tint(music.currentSection?.id == s.id ? .blue : .gray)
                        }
                    }
                }

                Button { mark() } label: {
                    Label("Mark", systemImage: "flag.fill")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .disabled(!camera.isRecording)

                if camera.isRecording {
                    Text("\(marks.count) marked").font(.caption).foregroundStyle(.secondary)
                }

                Button { camera.isRecording ? stop() : start() } label: {
                    Text(saving ? "Saving…" : (camera.isRecording ? "Stop" : "Record"))
                        .bold()
                        .frame(maxWidth: .infinity, minHeight: 56)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(saving)
            }
            .padding()
        }
    }

    private func loadSong() {
        if let song { music.load(song) } else { music.unload() }
    }

    private func start() {
        let s = Session(date: Date(), songID: songID, videoFileName: UUID().uuidString + ".mov")
        draft = s
        marks = []
        elapsed = 0
        camera.startRecording(to: Store.videoURL(s))
        music.startLog()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    // Press Mark right after an element: the clip covers 5 s before to 1 s after.
    private func mark() {
        let t = camera.currentVideoTime() ?? 0
        marks.append(Moment(time: t, start: max(0, t - 5), end: t + 1, source: .manual))
    }

    private func stop() {
        guard let base = draft else { return }
        saving = true
        Task {
            var s = base
            let duration = await camera.stopRecording()
            s.events = music.endLog()
            music.stopPlayback()
            s.duration = duration
            s.moments = marks.map { m in
                var m = m
                m.end = max(m.start, min(m.end, duration - 0.1))
                return m
            }
            store.update(s)
            draft = nil
            saving = false
            UIApplication.shared.isIdleTimerDisabled = false
            if !router.path.isEmpty { router.path.removeLast() }
            router.path.append(.review(s.id))
        }
    }
}

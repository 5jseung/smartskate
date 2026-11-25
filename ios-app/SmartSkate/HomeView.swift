import SwiftUI

struct HomeView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var router: Router

    var body: some View {
        NavigationStack(path: $router.path) {
            List {
                Section {
                    Button { router.path.append(.record) } label: {
                        Label("Start practice", systemImage: "record.circle")
                    }
                    NavigationLink(value: Route.songs) {
                        Label("Songs", systemImage: "music.note.list")
                    }
                }
                Section("Past sessions") {
                    let sessions = store.sessions.sorted { $0.date > $1.date }
                    if sessions.isEmpty {
                        Text("No sessions yet").foregroundStyle(.secondary)
                    }
                    ForEach(sessions) { s in
                        NavigationLink(value: Route.review(s.id)) {
                            VStack(alignment: .leading) {
                                Text(s.date.formatted(date: .abbreviated, time: .shortened))
                                Text("\(formatTime(s.duration)) · \(s.moments.count) moments · \(store.song(s.songID)?.title ?? "No music")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        offsets.map { sessions[$0] }.forEach(store.deleteSession)
                    }
                }
            }
            .navigationTitle("SmartSkate")
            .navigationDestination(for: Route.self) { route in
                destination(route)
            }
        }
    }

    @ViewBuilder
    private func destination(_ route: Route) -> some View {
        switch route {
        case .record:
            RecordView()
        case .review(let id):
            if let s = store.session(id) {
                ReviewView(session: s, song: store.song(s.songID))
            }
        case .songs:
            SongsView()
        case .song(let id):
            SongEditorView(songID: id)
        }
    }
}

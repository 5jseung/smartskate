import AVKit
import SwiftUI

/// After a session: watch it with the music rebuilt from the log.
struct ReviewView: View {
    @EnvironmentObject var store: Store
    let sessionID: UUID
    @StateObject private var synced: SyncedPlayer

    init(session: Session, song: Song?) {
        sessionID = session.id
        _synced = StateObject(wrappedValue: SyncedPlayer(session: session, song: song))
    }

    private var session: Session? { store.session(sessionID) }

    var body: some View {
        VStack(spacing: 8) {
            VideoPlayer(player: synced.player)
            TimelineBar(duration: session?.duration ?? 0,
                        events: session?.events ?? [],
                        moments: session?.moments ?? [],
                        current: synced.currentTime) { t in synced.seek(t) }
                .frame(height: 28)
                .padding(.horizontal)
            Text("Gray lines = music changes. Orange dots = marks.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
        .navigationTitle(session?.date.formatted(date: .abbreviated, time: .shortened) ?? "Session")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { synced.pause() }
    }
}

struct TimelineBar: View {
    let duration: Double
    let events: [MusicEvent]
    let moments: [Moment]
    let current: Double
    var onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let x: (Double) -> CGFloat = { t in duration > 0 ? CGFloat(t / duration) * w : 0 }
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.25)).frame(height: 8)
                ForEach(events.indices, id: \.self) { i in
                    Rectangle().fill(Color.gray).frame(width: 2, height: 16)
                        .offset(x: x(events[i].videoTime))
                }
                ForEach(moments) { m in
                    Circle().fill(m.label == nil ? Color.orange : Color.blue)
                        .frame(width: 10, height: 10)
                        .offset(x: x(m.time) - 5)
                }
                Rectangle().fill(Color.red).frame(width: 2, height: 24)
                    .offset(x: x(current))
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { v in
                guard w > 0 else { return }
                onSeek(max(0, min(duration, Double(v.location.x / w) * duration)))
            })
        }
    }
}

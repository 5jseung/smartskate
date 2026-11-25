import SwiftUI

@main
struct SmartSkateApp: App {
    @StateObject private var store = Store()
    @StateObject private var router = Router()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(store)
                .environmentObject(router)
        }
    }
}

enum Route: Hashable {
    case record
    case review(UUID)
    case songs
    case song(UUID)
}

final class Router: ObservableObject {
    @Published var path: [Route] = []
}

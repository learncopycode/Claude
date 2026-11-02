import SwiftUI
import SwiftData

@main
struct ZikrApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var assistant = AssistantService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(router)
                .environmentObject(assistant)
        }
        .modelContainer(for: [ZikrItem.self, DailyTally.self])
    }
}

/// Lets any screen switch tabs or open a counter (e.g. after "Add & start").
@MainActor
final class AppRouter: ObservableObject {
    enum Tab: Hashable { case counter, assistant, library }

    @Published var tab: Tab = .counter
    @Published var counterPath: [ZikrItem] = []

    func openCounter(_ item: ZikrItem) {
        tab = .counter
        counterPath = [item]
    }
}

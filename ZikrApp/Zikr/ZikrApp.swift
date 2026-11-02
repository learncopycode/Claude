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
                .preferredColorScheme(.dark)
                .tint(Theme.mint)
        }
        .modelContainer(for: [ZikrItem.self, DailyTally.self, CustomCollection.self])
    }
}

/// Screens that can be pushed on the Counter tab.
enum Route: Hashable {
    case counter(ZikrItem)
    case collection(String)
    case customCollection(CustomCollection)
    case names
    case duas(title: String, categories: [DuaCategory])
    case surahs
}

/// Lets any screen switch tabs or open a counter (e.g. after "Add & start").
@MainActor
final class AppRouter: ObservableObject {
    enum Tab: Hashable { case counter, assistant, library }

    @Published var tab: Tab = .counter
    @Published var path: [Route] = []
    /// Text to pre-fill in the Ask AI tab.
    @Published var pendingQuestion: String?

    func openCounter(_ item: ZikrItem) {
        tab = .counter
        path = [.counter(item)]
    }

    func openCollection(_ collection: CustomCollection) {
        tab = .counter
        path = [.customCollection(collection)]
    }

    func ask(_ question: String? = nil) {
        pendingQuestion = question
        tab = .assistant
    }
}

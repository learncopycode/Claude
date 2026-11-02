import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.tab) {
            AdhkarListView()
                .tabItem { Label("Counter", systemImage: "circle.circle") }
                .tag(AppRouter.Tab.counter)

            AssistantView()
                .tabItem { Label("Ask AI", systemImage: "sparkles") }
                .tag(AppRouter.Tab.assistant)

            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(AppRouter.Tab.library)
        }
    }
}

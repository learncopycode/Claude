import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        TabView(selection: $router.tab) {
            HomeView()
                .tabItem { Label("Counter", systemImage: "circle.circle") }
                .tag(AppRouter.Tab.counter)

            StatsView()
                .tabItem { Label("Stats", systemImage: "chart.bar.fill") }
                .tag(AppRouter.Tab.stats)

            AssistantView()
                .tabItem { Label("Ask AI", systemImage: "sparkles") }
                .tag(AppRouter.Tab.assistant)

            LibraryView()
                .tabItem { Label("Library", systemImage: "books.vertical") }
                .tag(AppRouter.Tab.library)
        }
    }
}

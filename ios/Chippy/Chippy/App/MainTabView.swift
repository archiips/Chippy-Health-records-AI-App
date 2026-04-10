import SwiftUI

struct MainTabView: View {
    @State private var coordinator = AppCoordinator()

    var body: some View {
        TabView {
            NavigationStack(path: $coordinator.libraryPath) {
                DocumentLibraryView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .documentDetail(let doc): DocumentDetailView(document: doc)
                        }
                    }
            }
            .tabItem { Label("Documents", systemImage: "doc.text") }

            NavigationStack(path: $coordinator.timelinePath) {
                HealthTimelineView()
                    .navigationDestination(for: Route.self) { route in
                        switch route {
                        case .documentDetail(let doc): DocumentDetailView(document: doc)
                        }
                    }
            }
            .tabItem { Label("Timeline", systemImage: "calendar") }

            NavigationStack {
                ChatView()
            }
            .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
        .environment(coordinator)
    }
}

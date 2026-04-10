import SwiftUI

// MARK: - Route

enum Route: Hashable {
    case documentDetail(HealthDocument)
}

// MARK: - AppCoordinator

@Observable
@MainActor
final class AppCoordinator {
    var libraryPath = NavigationPath()
    var timelinePath = NavigationPath()

    func pushToLibrary(_ route: Route) {
        libraryPath.append(route)
    }

    func pushToTimeline(_ route: Route) {
        timelinePath.append(route)
    }

    func popLibraryToRoot() {
        libraryPath = NavigationPath()
    }

    func popTimelineToRoot() {
        timelinePath = NavigationPath()
    }
}

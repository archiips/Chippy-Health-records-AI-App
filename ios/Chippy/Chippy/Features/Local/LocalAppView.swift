import SwiftUI
import SwiftData
import VisionKit

struct LocalAppView: View {
    var body: some View {
        TabView {
            Tab("Records", systemImage: "doc.text") { NavigationStack { LocalLibraryView() } }
            Tab("Timeline", systemImage: "calendar") { NavigationStack { ReviewedTimelineView() } }
            Tab("Chat", systemImage: "bubble.left.and.bubble.right") { NavigationStack { LocalChatView() } }
            Tab("Settings", systemImage: "gearshape") { NavigationStack { LocalSettingsView() } }
        }
    }
}

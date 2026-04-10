import SwiftData

enum AppModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            HealthDocument.self,
            AnalysisResult.self,
            HealthEvent.self,
            ChatMessage.self,
        ])

        // cloudKitDatabase: .none — Apple prohibits health data in iCloud
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}

import Foundation
import SwiftData

enum AppModelContainer {
    static let local = makeProtectedContainer(name: "local-records")

    static func cloud(for userID: String) -> ModelContainer {
        guard let id = UUID(uuidString: userID) else { fatalError("Invalid account identity") }
        return makeProtectedContainer(name: "cloud-\(id.uuidString)")
    }

    private static func makeProtectedContainer(name: String) -> ModelContainer {
        do {
            let directory = URL.applicationSupportDirectory.appending(path: "protected-record-stores", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete])
            var protectedDirectory = directory
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try protectedDirectory.setResourceValues(values)
            let schema = Schema([HealthDocument.self, AnalysisResult.self, HealthEvent.self, ChatMessage.self, RecordFact.self])
            let config = ModelConfiguration(name, schema: schema, url: directory.appending(path: "\(name).store"), cloudKitDatabase: .none)
            return try ModelContainer(for: schema, configurations: [config])
        } catch { fatalError("Could not open protected record store") }
    }
}

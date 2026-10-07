import Foundation

struct LegacyCacheCleanup {
    let root: URL
    init(root: URL = .applicationSupportDirectory) { self.root = root }
    private var targets: [URL] {
        ["documents", "default.store", "default.store-wal", "default.store-shm"].map { root.appending(path: $0) }
    }
    var hasLegacyFiles: Bool { targets.contains { FileManager.default.fileExists(atPath: $0.path) } }
    func remove() throws {
        for target in targets where FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
    }
}

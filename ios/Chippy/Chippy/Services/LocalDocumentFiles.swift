import Foundation

struct LocalDocumentFiles: Sendable {
    let directory: URL

    init(directory: URL = URL.applicationSupportDirectory.appending(path: "local-record-files", directoryHint: .isDirectory)) {
        self.directory = directory
    }

    func save(_ data: Data, extension fileExtension: String) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                                attributes: [.protectionKey: FileProtectionType.complete])
        var protectedDirectory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try protectedDirectory.setResourceValues(values)
        let url = directory.appending(path: UUID().uuidString).appendingPathExtension(fileExtension)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }

    func remove(_ url: URL) throws {
        guard url.resolvingSymlinksInPath().deletingLastPathComponent().standardizedFileURL == directory.resolvingSymlinksInPath().standardizedFileURL else {
            throw CocoaError(.fileWriteNoPermission)
        }
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    func removeAll() throws {
        guard FileManager.default.fileExists(atPath: directory.path) else { return }
        try FileManager.default.removeItem(at: directory)
    }
}

enum CloudDocumentFiles {
    static func store(userID: String) throws -> LocalDocumentFiles {
        guard let id = UUID(uuidString: userID) else { throw ImportError.notAuthenticated }
        return LocalDocumentFiles(directory: URL.applicationSupportDirectory
            .appending(path: "cloud-record-files", directoryHint: .isDirectory)
            .appending(path: id.uuidString, directoryHint: .isDirectory))
    }
}

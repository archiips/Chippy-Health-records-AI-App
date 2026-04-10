import Foundation
import SwiftData

@MainActor
struct DocumentRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func insert(_ document: HealthDocument) throws {
        context.insert(document)
        try context.save()
    }

    func fetchAll() throws -> [HealthDocument] {
        let descriptor = FetchDescriptor<HealthDocument>(
            sortBy: [SortDescriptor(\.uploadedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func fetchById(_ id: String) throws -> HealthDocument? {
        var descriptor = FetchDescriptor<HealthDocument>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetchProcessing() throws -> [HealthDocument] {
        let all = try fetchAll()
        return all.filter { $0.processingStatus == .processing }
    }

    func updateStatus(_ id: String, status: ProcessingStatus) throws {
        guard let doc = try fetchById(id) else { return }
        doc.processingStatus = status
        try context.save()
    }

    func delete(_ document: HealthDocument) throws {
        context.delete(document)
        try context.save()
    }
}

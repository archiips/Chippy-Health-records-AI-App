import Testing
import UIKit
import PhotosUI
import SwiftData
@testable import Chippy

@MainActor
@Suite(.serialized)
struct PhotoImportTests {
    @Test func unreadablePhotoFinishesInsteadOfSilentlyAbandoningThePicker() async throws {
        var completed = false
        var cancelled = false
        let coordinator = PhotoPicker.Coordinator(onCompletion: { _ in completed = true }, onCancellation: { cancelled = true })
        coordinator.loadImage(from: NSItemProvider())
        for _ in 0..<100 where !completed && !cancelled { try await Task.sleep(for: .milliseconds(10)) }
        #expect(cancelled)
        #expect(!completed)
    }

    @Test func providerLoadErrorReportsFailureAndEndsLoading() async throws {
        var completed = false
        var cancelled = false
        var loading = false
        var failure: String?
        let provider = NSItemProvider()
        provider.registerObject(ofClass: UIImage.self, visibility: .all) { completion in
            completion(nil, NSError(domain: "SyntheticPhotoProvider", code: 1))
            return nil
        }
        let coordinator = PhotoPicker.Coordinator(onCompletion: { _ in completed = true }, onCancellation: { cancelled = true },
            onFailure: { failure = $0; loading = false }, onLoading: { loading = true })
        coordinator.loadImage(from: provider)
        for _ in 0..<200 where failure == nil { try await Task.sleep(for: .milliseconds(10)) }
        #expect(failure != nil)
        #expect(!loading && !completed && !cancelled)
    }

    @Test func readableProviderCompletesWithTheSelectedImage() async throws {
        var result: UIImage?
        var failed = false
        var loadingStarted = false
        let url = try #require(Bundle(for: LocalModelEvaluationTests.self).url(forResource: "provider-sample-lab", withExtension: "jpg"))
        let image = try #require(UIImage(contentsOfFile: url.path))
        let coordinator = PhotoPicker.Coordinator(onCompletion: { result = $0 }, onCancellation: { failed = true },
            onFailure: { _ in failed = true }, onLoading: { loadingStarted = true })
        coordinator.loadImage(from: NSItemProvider(object: image))
        for _ in 0..<200 where result == nil && !failed { try await Task.sleep(for: .milliseconds(10)) }
        #expect(loadingStarted)
        #expect(result?.size == image.size)
        #expect(!failed)
    }

    @Test func photoLoadedAfterResetCannotRecreateDeletedRecords() async throws {
        let schema = Schema([HealthDocument.self, RecordFact.self, ChatMessage.self, HealthEvent.self, AnalysisResult.self])
        let store = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let revisionAtSelection = LocalRecordLifecycle.shared.revision
        LocalRecordLifecycle.shared.invalidatePendingWork()
        let url = try #require(Bundle(for: LocalModelEvaluationTests.self).url(forResource: "provider-sample-lab", withExtension: "jpg"))
        let image = try #require(UIImage(contentsOfFile: url.path))
        let importer = LocalImportViewModel()
        await importer.importImages([image], context: store.mainContext, expectedRevision: revisionAtSelection)
        let documents = try store.mainContext.fetch(FetchDescriptor<HealthDocument>())
        defer { for document in documents { try? LocalDocumentFiles().remove(document.resolvedFileURL) } }
        #expect(documents.isEmpty)
        #expect(importer.importedDocument == nil)
    }

    @Test func failedLocalImportCanBeRetriedWithoutOldErrorOrRemoteUpload() async throws {
        let schema = Schema([HealthDocument.self, RecordFact.self, ChatMessage.self, HealthEvent.self, AnalysisResult.self])
        let store = try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        let importer = LocalImportViewModel()
        await importer.importImages([], context: store.mainContext)
        #expect(importer.errorMessage != nil)
        #expect(!importer.isProcessing)
        #expect(try store.mainContext.fetch(FetchDescriptor<HealthDocument>()).isEmpty)
        let url = try #require(Bundle(for: LocalModelEvaluationTests.self).url(forResource: "provider-sample-lab", withExtension: "jpg"))
        let image = try #require(UIImage(contentsOfFile: url.path))
        await importer.importImages([image], context: store.mainContext)
        let documents = try store.mainContext.fetch(FetchDescriptor<HealthDocument>())
        let imported = try #require(documents.first)
        defer { try? LocalDocumentFiles().remove(imported.resolvedFileURL) }
        #expect(documents.count == 1)
        #expect(importer.errorMessage == nil)
        #expect(!importer.isProcessing)
        #expect(imported.remoteId == nil)
        #expect(imported.pages.count == 1)
        #expect(imported.pages[0].text.contains("147"))
        #expect(imported.thumbnailData != nil)
    }
}

import XCTest
import FoundationModels
@testable import Chippy

final class LocalModelEvaluationTests: XCTestCase {
    @MainActor
    func testSyntheticDeviceBenchmark() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Measure on-device extraction on physical hardware, not a simulator proxy.")
        #else
        guard SystemLanguageModel.default.isAvailable else {
            throw XCTSkip("Run on an Apple Intelligence device with its on-device model downloaded. Simulator results do not measure model quality.")
        }
        let pages = [
            DocumentPage(number: 1, text: "SYNTHETIC RECORD — not a real patient. On 2026-10-06: Glucose 105 mg/dL. Reference range 70-100 mg/dL."),
            DocumentPage(number: 2, text: "SYNTHETIC RECORD — not a real patient. On 2024-01-12: Medication mentioned: ExampleDrug 5 mg. This is a historical record; current use is unknown.")
        ]
        let start = Date()
        let results = try await LocalAnalysisService().extract(pages: pages)
        let expected = [(page: 1, name: "Glucose", value: "105"), (page: 2, name: "ExampleDrug", value: "5")]
        let hits = expected.filter { expected in
            results.contains { $0.pageNumber == expected.page && $0.candidate.name == expected.name && $0.candidate.value.contains(expected.value) }
        }.count
        let report: [String: Any] = [
            "synthetic_only": true, "elapsed_seconds": Date().timeIntervalSince(start),
            "expected_facts": expected.count, "expected_facts_found": hits,
            "candidates": try results.map { result in
                ["page": result.pageNumber, "fact": try JSONSerialization.jsonObject(with: JSONEncoder().encode(result.candidate))] as [String: Any]
            }
        ]
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = "Synthetic on-device extraction benchmark"
        attachment.lifetime = .keepAlways
        add(attachment)
        for result in results {
            let page = try XCTUnwrap(pages.first { $0.number == result.pageNumber })
            XCTAssertTrue(FactEvidence.validate(result.candidate, in: page))
        }
        // Recall is reported, not assumed. This toy fixture is not a clinical-quality gate.
        #endif
    }
}

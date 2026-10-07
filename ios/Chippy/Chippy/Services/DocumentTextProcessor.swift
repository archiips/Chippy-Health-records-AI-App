import Foundation
import PDFKit
import Vision
import ImageIO

struct DocumentPage: Codable, Identifiable, Sendable {
    var number: Int
    var text: String
    var id: Int { number }

    func segments(maxCharacters: Int = 1600) -> [DocumentPage] {
        guard maxCharacters > 0 else { return [] }
        var start = text.startIndex
        var result: [DocumentPage] = []
        while start < text.endIndex {
            let end = text.index(start, offsetBy: maxCharacters, limitedBy: text.endIndex) ?? text.endIndex
            result.append(DocumentPage(number: number, text: String(text[start..<end])))
            start = end
        }
        return result
    }
}

enum DocumentTextError: LocalizedError {
    case unreadable, noPages
    var errorDescription: String? {
        switch self {
        case .unreadable: "The document could not be read. Try another file or a clearer scan."
        case .noPages: "The document has no pages."
        }
    }
}

actor DocumentTextProcessor {
    func pdfPages(_ data: Data) throws -> [DocumentPage] {
        guard let pdf = PDFDocument(data: data), !pdf.isLocked else { throw DocumentTextError.unreadable }
        guard pdf.pageCount > 0 else { throw DocumentTextError.noPages }
        var pages: [DocumentPage] = []
        for index in 0..<pdf.pageCount {
            try Task.checkCancellation()
            guard let page = pdf.page(at: index) else { throw DocumentTextError.unreadable }
            var text = (page.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            // Rendering fallback handles scanned pages without a text layer.
            if text.isEmpty {
                let image = page.thumbnail(of: CGSize(width: 1600, height: 2200), for: .mediaBox)
                guard let data = image.pngData() else { throw DocumentTextError.unreadable }
                text = try recognize(data)
            }
            pages.append(DocumentPage(number: index + 1, text: text))
        }
        return pages
    }

    func imagePages(_ images: [Data]) throws -> [DocumentPage] {
        guard !images.isEmpty else { throw DocumentTextError.noPages }
        return try images.enumerated().map { index, data in
            try Task.checkCancellation()
            return DocumentPage(number: index + 1, text: try recognize(data))
        }
    }

    private func recognize(_ data: Data) throws -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw DocumentTextError.unreadable }
        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let rawOrientation = properties?[kCGImagePropertyOrientation] as? UInt32 ?? 1
        let orientation = CGImagePropertyOrientation(rawValue: rawOrientation) ?? .up
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        try VNImageRequestHandler(cgImage: image, orientation: orientation).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}

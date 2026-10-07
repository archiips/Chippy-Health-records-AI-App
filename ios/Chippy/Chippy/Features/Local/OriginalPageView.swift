import SwiftUI
import SwiftData
import PDFKit

struct OriginalPageView: UIViewRepresentable {
    let url: URL
    let pageNumber: Int
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = PDFDocument(url: url)
        if let page = view.document?.page(at: pageNumber - 1) { view.go(to: page) }
        return view
    }
    func updateUIView(_ view: PDFView, context: Context) {
        if let page = view.document?.page(at: pageNumber - 1) { view.go(to: page) }
    }
}

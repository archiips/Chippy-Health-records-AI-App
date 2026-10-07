import SwiftUI
import PDFKit

struct RecordPagePreview: View {
    let url: URL
    let pageNumber: Int
    @State private var image: UIImage?
    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 240)
                    .frame(maxWidth: .infinity).padding(12).background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel("Original document, page \(pageNumber)")
            } else { Label("Open the original to check this page", systemImage: "doc.richtext").foregroundStyle(.secondary) }
        }.task(id: pageNumber) {
            image = PDFDocument(url: url)?.page(at: pageNumber - 1)?.thumbnail(of: CGSize(width: 500, height: 680), for: .mediaBox)
        }
    }
}

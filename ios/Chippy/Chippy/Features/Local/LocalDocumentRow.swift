import SwiftUI

struct LocalDocumentRow: View {
    let document: HealthDocument
    private var reviewedCount: Int { document.recordFacts.filter(\.isConfirmed).count }
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Group {
                if let data = document.thumbnailData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else { Image(systemName: "doc.richtext").font(.title).foregroundStyle(Color.accentColor).frame(maxWidth: .infinity, maxHeight: .infinity).background(Color.lavendorTint) }
            }.frame(width: 62, height: 82).clipShape(RoundedRectangle(cornerRadius: 10)).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 7) {
                Text(document.filename).font(.headline).lineLimit(2)
                Text(document.documentType.displayName).font(.caption).bold().foregroundStyle(Color.accentColor)
                Text("\(document.pages.count) pages · \(reviewedCount) reviewed facts").font(.caption).foregroundStyle(.secondary)
                Label(reviewedCount == 0 ? "Needs review" : "Reviewed facts available", systemImage: reviewedCount == 0 ? "doc.viewfinder" : "checkmark.shield")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }.padding(.vertical, 8).accessibilityElement(children: .combine)
    }
}

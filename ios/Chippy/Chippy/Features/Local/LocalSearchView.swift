import SwiftUI
import SwiftData
import VisionKit

struct LocalSearchView: View {
    @Query private var documents: [HealthDocument]
    @State private var query = ""
    var body: some View {
        List {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView("Search your source text", systemImage: "magnifyingglass", description: Text("Search words as they appear in a record. Results include the source page."))
            } else {
                ForEach(documents) { document in
                    ForEach(document.pages.filter { $0.text.localizedCaseInsensitiveContains(query) }) { page in
                        NavigationLink { RecordReviewView(document: document, initialPage: page.number) } label: {
                            VStack(alignment: .leading) {
                                Text(document.filename).font(.headline)
                                Text("Page \(page.number)").font(.caption)
                                Text(page.text).lineLimit(4).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Search")
        .searchable(text: $query, prompt: "Find a word in your records")
    }
}

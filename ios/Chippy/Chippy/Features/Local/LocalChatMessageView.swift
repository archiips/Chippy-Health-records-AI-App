import SwiftUI

struct LocalChatMessageView: View {
    let message: ChatMessage
    let documents: [HealthDocument]
    private var user: Bool { message.role == .user }
    var body: some View {
        HStack {
            if user { Spacer(minLength: 36) }
            VStack(alignment: .leading, spacing: 14) {
                Text(user ? "You" : "Chippy").font(.subheadline).bold().foregroundStyle(.secondary)
                Text(message.content).textSelection(.enabled).font(.body)
                    .accessibilityIdentifier(user ? "local-user-message" : "local-assistant-message-\(message.id)")
                if !user {
                    ForEach(Array(message.localSources.prefix(2).enumerated()), id: \.element.id) { index, source in
                        sourceLink(source, index: index)
                    }
                    if message.localSources.count > 2 {
                        DisclosureGroup("\(message.localSources.count - 2) more source pages") {
                            ForEach(Array(message.localSources.dropFirst(2).enumerated()), id: \.element.id) { index, source in
                                sourceLink(source, index: index + 2)
                            }
                        }.font(.subheadline)
                    }
                    Text("For informational purposes only. Consult your doctor.").font(.caption).foregroundStyle(.secondary)
                }
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                .background(user ? Color.lavendorTint : Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
            if !user { Spacer(minLength: 12) }
        }
    }
    @ViewBuilder
    private func sourceLink(_ source: LocalRecordSource, index: Int) -> some View {
        if let doc = documents.first(where: { $0.id == source.documentID }) {
            NavigationLink { RecordReviewView(document: doc, initialPage: source.pageNumber) } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "doc.text").foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("[\(index + 1)] \(doc.filename)").font(.subheadline).bold().lineLimit(2)
                        Text("Page \(source.pageNumber) · \(source.reviewed ? "Reviewed fact" : "Original OCR")").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                }.padding(12).background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain)
        }
    }
}

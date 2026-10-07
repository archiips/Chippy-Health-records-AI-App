import SwiftUI

struct RecordEventCard: View {
    let event: ReviewedRecordEvent
    let document: HealthDocument
    let isLast: Bool
    private var pages: String { Array(Set(event.facts.map(\.pageNumber))).sorted().map(String.init).joined(separator: ", ") }
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Image(systemName: RecordKindStyle.icon(event.kind))
                    .font(.subheadline).foregroundStyle(RecordKindStyle.color(event.kind))
                    .frame(width: 32, height: 38).background(Color.lavendorTint, in: RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
                if !isLast { Rectangle().fill(Color.lavendorCard).frame(width: 2).frame(maxHeight: .infinity).padding(.top, 6) }
            }.frame(width: 32)
            NavigationLink { RecordReviewView(document: document, initialPage: event.facts.first?.pageNumber ?? 1) } label: {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(RecordKindStyle.name(event.kind)).font(.headline).foregroundStyle(RecordKindStyle.color(event.kind))
                            if let date = event.date {
                                Text(RecordTimeline.dateLabel(date)).font(.subheadline).foregroundStyle(.secondary)
                            } else { Text("Date as recorded: \(event.dateText ?? "not recorded")").font(.subheadline).foregroundStyle(.secondary) }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    }
                    ForEach(event.facts) { fact in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(fact.name).font(.subheadline).bold()
                                Spacer(minLength: 8)
                                Text("\(fact.value)\(fact.unit.map { " \($0)" } ?? "")").font(.headline).monospacedDigit()
                            }
                            if fact.kind == "lab" { Text("Recorded range: \(fact.referenceRange ?? "not recorded")").font(.caption).foregroundStyle(.secondary) }
                        }.accessibilityElement(children: .combine)
                    }
                    Divider()
                    Label("\(document.filename) · pages \(pages)", systemImage: "doc.text")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    if event.kind == "medication" { Text("Historical mention, not a current medication list.").font(.caption).foregroundStyle(.secondary) }
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            }.buttonStyle(.plain)
        }.padding(.bottom, 16)
    }
}

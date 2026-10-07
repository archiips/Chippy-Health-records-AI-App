import SwiftUI
import SwiftData

struct ReviewedTimelineView: View {
    @Query private var facts: [RecordFact]
    @Query private var documents: [HealthDocument]
    @State private var showExport = false
    @State private var showTrends = false
    @State private var category: String?
    @State private var range: DateRange = .all
    private var reviewed: [RecordFact] { facts.filter(\.isConfirmed) }
    private var events: [ReviewedRecordEvent] { RecordTimeline.events(from: facts, kind: category, after: range.cutoff) }
    private var pending: [HealthDocument] { documents.filter { $0.recordFacts.contains { !$0.isConfirmed } || $0.recordFacts.isEmpty } }
    private var sections: [String] {
        var result: [String] = []
        for event in events { let key = month(event); if !result.contains(key) { result.append(key) } }
        return result
    }
    private func month(_ event: ReviewedRecordEvent) -> String {
        event.date.map { RecordTimeline.dateLabel($0, monthOnly: true) } ?? "Date not recorded"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20, pinnedViews: .sectionHeaders) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("\(events.count) reviewed events", systemImage: "checkmark.shield")
                        Spacer()
                        Text("On this device").foregroundStyle(.secondary)
                    }.font(.caption)
                    Text("Reviewed records, ordered by the date recorded in each document.").font(.subheadline).foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button { category = nil } label: { Text("All").padding(.horizontal, 16).frame(minHeight: 44).background(category == nil ? Color.lavendorCard : Color(.secondarySystemGroupedBackground), in: Capsule()) }
                            ForEach(RecordKindStyle.kinds, id: \.self) { kind in
                                Button { category = category == kind ? nil : kind } label: {
                                    Label(RecordKindStyle.name(kind), systemImage: RecordKindStyle.icon(kind)).padding(.horizontal, 14).frame(minHeight: 44)
                                        .background(category == kind ? Color.lavendorCard : Color(.secondarySystemGroupedBackground), in: Capsule())
                                }.accessibilityAddTraits(category == kind ? .isSelected : [])
                            }
                        }.font(.subheadline).buttonStyle(.plain)
                    }
                    Picker("Date Range", selection: $range) { ForEach(DateRange.allCases, id: \.self) { Text($0.label).tag($0) } }.pickerStyle(.segmented)
                }
                if !pending.isEmpty && category == nil && range == .all {
                    NavigationLink { List(pending) { document in NavigationLink { RecordReviewView(document: document) } label: { Label(document.filename, systemImage: "doc.viewfinder") } }.navigationTitle("Needs Review") } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.viewfinder").font(.title2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(pending.count) records need review").font(.subheadline).bold()
                                Text("Check dates and facts to add them to your history.").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(); Image(systemName: "chevron.right").font(.caption)
                        }.padding(16).background(Color.lavendorTint, in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain)
                }
                if events.isEmpty {
                    ContentUnavailableView(reviewed.isEmpty ? "Build your health history" : "No events in this view", systemImage: "calendar.badge.clock",
                        description: Text(reviewed.isEmpty ? "Photograph a medical record, then review its facts and dates. They’ll appear here with a link to the original." : "Try another category or date range. Undated records appear under All."))
                }
                ForEach(sections, id: \.self) { section in
                    let sectionEvents = events.filter { month($0) == section }
                    Section {
                        ForEach(sectionEvents) { event in
                            if let document = documents.first(where: { $0.id == event.documentID }) {
                                RecordEventCard(event: event, document: document, isLast: event.id == sectionEvents.last?.id)
                            }
                        }
                    } header: {
                        Text(section).font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 12)
                            .background(Color(.systemGroupedBackground))
                    }
                }
                Text("Historical records do not establish current medications or a diagnosis. For informational purposes only.").font(.caption).foregroundStyle(.secondary)
            }.padding(.horizontal, 20).padding(.top, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Timeline")
        .toolbar {
            Button("Lab Trends", systemImage: "chart.xyaxis.line") { showTrends = true }.disabled(!reviewed.contains { $0.kind == "lab" })
            Button("Export", systemImage: "square.and.arrow.up") { showExport = true }.disabled(reviewed.isEmpty)
        }
        .sheet(isPresented: $showExport) { RecordExportView(facts: reviewed, documents: documents) }
        .sheet(isPresented: $showTrends) { NavigationStack { LocalLabTrendsView(facts: reviewed).toolbar { Button("Done") { showTrends = false } } } }
    }
}

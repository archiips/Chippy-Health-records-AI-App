import SwiftUI
import Charts

struct LocalLabTrendsView: View {
    let facts: [RecordFact]
    private var groups: [String: [RecordFact]] { RecordLabSeries.groups(facts) }
    var body: some View {
        List {
            Text("Reviewed numeric results, grouped by test and recorded unit. These charts do not interpret clinical significance.")
                .font(.subheadline).foregroundStyle(.secondary)
            if groups.isEmpty {
                ContentUnavailableView("No dated numeric results", systemImage: "chart.xyaxis.line", description: Text("Review a numeric lab value, a recorded unit, range, and date to see it here."))
            }
            ForEach(groups.keys.sorted(), id: \.self) { name in
                let points = (groups[name] ?? []).sorted { ($0.eventDate ?? .distantPast) < ($1.eventDate ?? .distantPast) }
                Section(name) {
                    Chart(points) { fact in
                        if let date = fact.eventDate, let value = Double(fact.value) {
                            PointMark(x: .value("Recorded date", date), y: .value(name, value)).symbolSize(70)
                                .accessibilityLabel("\(fact.name): \(fact.value) \(fact.unit ?? "unit not recorded"), recorded \(fact.dateText ?? "date not recorded"), reference range \(fact.referenceRange ?? "not recorded")")
                        }
                    }.frame(height: 180).foregroundStyle(Color.accentColor)
                    ForEach(points) { fact in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(fact.dateText ?? "") · \(fact.value) \(fact.unit ?? "")").font(.subheadline).bold()
                            Text("Recorded range: \(fact.referenceRange ?? "not recorded")").font(.caption).foregroundStyle(.secondary)
                        }.accessibilityElement(children: .combine)
                    }
                }
            }
        }.navigationTitle("Lab Trends")
    }
}

import SwiftUI
import SwiftData

struct HealthTimelineView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.modelContext) private var context
    @Query(sort: \HealthDocument.uploadedAt, order: .reverse) private var documents: [HealthDocument]

    @State private var events: [HealthEventDTO] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var categoryFilter: String? = nil
    @State private var dateRange: DateRange = .all

    private var filtered: [HealthEventDTO] {
        var result = events
        if let cat = categoryFilter {
            result = result.filter { $0.category == cat }
        }
        let cutoff = dateRange.cutoff
        if let cutoff {
            result = result.filter { ($0.eventDate ?? .distantPast) >= cutoff }
        }
        return result
    }

    private var grouped: [(String, [HealthEventDTO])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        var dict: [(String, [HealthEventDTO])] = []
        var seen: [String: Int] = [:]
        for event in filtered {
            let key = event.eventDate.map { formatter.string(from: $0) } ?? "Unknown Date"
            if let idx = seen[key] {
                dict[idx].1.append(event)
            } else {
                seen[key] = dict.count
                dict.append((key, [event]))
            }
        }
        return dict
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filters always pinned at top
            filterBar
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 10)

            dateRangePicker
                .padding(.horizontal)
                .padding(.bottom, 12)

            Divider()

            // Content area
            if isLoading && events.isEmpty {
                skeletonContent
            } else if filtered.isEmpty {
                emptyContent
            } else {
                eventList
            }
        }
        .navigationTitle("Timeline")
        .toolbar { toolbarContent }
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: - Skeleton

    private var skeletonContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(0..<6, id: \.self) { _ in
                    HStack(alignment: .top, spacing: 12) {
                        SkeletonView(cornerRadius: 6).frame(width: 12, height: 12).padding(.top, 4)
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonView().frame(width: 80, height: 11)
                            SkeletonView().frame(height: 15)
                            SkeletonView().frame(width: 200, height: 11)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 16)
        }
        .accessibilityLabel("Loading timeline")
    }

    // MARK: - Event list

    private var eventList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let error = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                        Text(error)
                            .font(.subheadline)
                        Spacer()
                        Button("Dismiss") { errorMessage = nil }
                            .font(.subheadline)
                    }
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: .sectionHeaders) {
                    ForEach(grouped, id: \.0) { section, sectionEvents in
                        Section {
                            ForEach(Array(sectionEvents.enumerated()), id: \.element.id) { idx, event in
                                Button {
                                    if let doc = document(for: event) {
                                        coordinator.pushToTimeline(.documentDetail(doc))
                                    }
                                } label: {
                                    TimelineRow(
                                        event: event,
                                        isLast: idx == sectionEvents.count - 1,
                                        document: document(for: event)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(document(for: event) == nil)
                                .scrollTransition { content, phase in
                                    content
                                        .opacity(phase.isIdentity ? 1 : 0.5)
                                        .offset(x: phase.isIdentity ? 0 : -8)
                                }
                            }
                        } header: {
                            Text(section)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.bar)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Empty content

    private var emptyContent: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 52))
                .foregroundStyle(Color.accentColor.opacity(0.6))
            Text(categoryFilter != nil
                 ? "No \(EventCategory(rawValue: categoryFilter!)?.displayName ?? "") Events"
                 : "No Timeline Events")
                .font(.title3)
                .fontWeight(.semibold)
            Text(categoryFilter != nil
                 ? "No events of this type found in your documents."
                 : "Upload medical documents to build your health timeline.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Filter bar

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(label: "All", isSelected: categoryFilter == nil) {
                    categoryFilter = nil
                }
                ForEach(EventCategory.allCases, id: \.self) { cat in
                    FilterChip(label: cat.displayName, isSelected: categoryFilter == cat.rawValue) {
                        categoryFilter = categoryFilter == cat.rawValue ? nil : cat.rawValue
                    }
                }
            }
        }
    }

    private var dateRangePicker: some View {
        Picker("Date Range", selection: $dateRange) {
            ForEach(DateRange.allCases, id: \.self) { range in
                Text(range.label).tag(range)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isLoading && !events.isEmpty {
                ProgressView().controlSize(.small)
            }
        }
    }

    // MARK: - Helpers

    private func load() async {
        guard let token = await authManager.validToken() else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            events = try await TimelineService.shared.fetchEvents(token: token)
            withAnimation { errorMessage = nil }
        } catch {
            withAnimation { errorMessage = error.localizedDescription }
        }
    }

    private func document(for event: HealthEventDTO) -> HealthDocument? {
        documents.first { $0.remoteId == event.documentId }
    }
}

// MARK: - DateRange

enum DateRange: String, CaseIterable {
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case all = "All"

    var label: String { rawValue }

    var cutoff: Date? {
        let cal = Calendar.current
        switch self {
        case .threeMonths: return cal.date(byAdding: .month, value: -3, to: .now)
        case .sixMonths:   return cal.date(byAdding: .month, value: -6, to: .now)
        case .oneYear:     return cal.date(byAdding: .year, value: -1, to: .now)
        case .all:         return nil
        }
    }
}

// MARK: - TimelineRow

private struct TimelineRow: View {
    let event: HealthEventDTO
    let isLast: Bool
    let document: HealthDocument?

    private var category: EventCategory? { EventCategory(rawValue: event.category) }
    private var color: Color { category?.color ?? .gray }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Spine
            VStack(spacing: 0) {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)
                if !isLast {
                    Rectangle()
                        .fill(color.opacity(0.3))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            .frame(width: 12)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Label(category?.displayName ?? event.category.capitalized,
                          systemImage: category?.systemImage ?? "circle")
                        .font(.caption)
                        .foregroundStyle(color)
                    Spacer()
                    if let date = event.eventDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(event.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let summary = event.summary, !summary.isEmpty {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                if document != nil {
                    Text("View document →")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }
            .padding(.bottom, 16)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(category?.displayName ?? event.category): \(event.title). \(event.summary ?? "")")
    }
}

// MARK: - FilterChip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.accentColor : Color.lavendorTint,
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(
                        isSelected ? Color.clear : Color.accentColor.opacity(0.2),
                        lineWidth: 1
                    )
                )
                .foregroundStyle(isSelected ? .white : Color.accentColor)
        }
        .animation(.spring(duration: 0.25), value: isSelected)
    }
}

// MARK: - EventCategory color

extension EventCategory {
    var color: Color {
        switch self {
        case .diagnosis: .red
        case .medication: .blue
        case .lab: .purple
        case .procedure: .orange
        case .visit: .green
        case .imaging: .indigo
        case .insurance: .gray
        }
    }
}

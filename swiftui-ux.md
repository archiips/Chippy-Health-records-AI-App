# SwiftUI UI/UX — Chippy Reference

**Tags:** #swiftui #uiux #ios #accessibility #animations
**Related:** [[wiki/healthrecords-ai-app/swift-ios-research]], [[wiki/healthrecords-ai-app/architecture]]
**Source:** Research — April 2026

---

## State Management (@Observable, iOS 17+)

**Use `@Observable` + `@MainActor` — not `ObservableObject`.**

```swift
@Observable
@MainActor
class DocumentLibraryViewModel {
    var documents: [HealthDocument] = []
    var isLoading = false
    // All stored properties auto-observable — no @Published needed
}

struct DocumentLibraryView: View {
    @State private var viewModel = DocumentLibraryViewModel()  // NOT @StateObject
}
```

**Critical caveat:** `@Observable` is NOT a drop-in for `ObservableObject` — `@State` caches instances differently. Always instantiate `@Observable` classes with `@State` in the owning view.

---

## Navigation (NavigationStack + Enum Routing)

```swift
// AppCoordinator.swift
@Observable
@MainActor
class AppCoordinator {
    var path = NavigationPath()

    enum Route: Hashable {
        case documentDetail(HealthDocument)
        case chat([HealthDocument])
        case explainer(AnalysisResult)
    }

    func push(_ route: Route) { path.append(route) }
    func pop() { path.removeLast() }
    func popToRoot() { path.removeLast(path.count) }
}

// Usage
NavigationStack(path: $coordinator.path) {
    DocumentLibraryView()
        .navigationDestination(for: AppCoordinator.Route.self) { route in
            switch route {
            case .documentDetail(let doc): DocumentDetailView(document: doc)
            case .chat(let docs): ChatView(documents: docs)
            case .explainer(let result): ExplainerView(result: result)
            }
        }
}
```

**Rules:**
- One `NavigationStack` per tab — each tab maintains independent history
- Never mutate the path during a view update — always from actions/tasks
- Keep coordinator `@Observable`, inject via `@Environment`

---

## List vs LazyVStack (Document Library)

**Use `List` for the main document library** — superior memory + scroll performance (view reuse, like UITableView). Use `LazyVStack` only when you need scroll-based animations (e.g., timeline parallax).

```swift
// Document library — use List
List(documents) { doc in
    DocumentCard(document: doc)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
}
.listStyle(.plain)

// Timeline with scroll effects — use LazyVStack
ScrollView {
    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
        ForEach(groupedEvents) { section in
            Section(header: TimelineSectionHeader(date: section.date)) {
                ForEach(section.events) { event in
                    TimelineRow(event: event)
                        .scrollTransition { content, phase in
                            content.opacity(phase.isIdentity ? 1 : 0.4)
                        }
                }
            }
        }
    }
    .contentMargins(.horizontal, 16, for: .scrollContent)
}
```

---

## Sheets and Modals

```swift
// Scan/import flow — fullScreenCover (no pull-down dismiss, immersive)
.fullScreenCover(isPresented: $showScanner) {
    DocumentScannerView()
        .interactiveDismissDisabled()  // prevent accidental dismiss mid-scan
}

// Document preview — sheet with variable height
.sheet(item: $selectedDocument) { doc in
    DocumentPreviewView(document: doc)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
}

// Dismiss inside presented view
struct DocumentPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Button("Done") { dismiss() }
    }
}
```

---

## Document Card Component

```swift
struct DocumentCard: View {
    let document: HealthDocument
    @Namespace private var animation

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail (generated via QLThumbnailGenerator, cached in SwiftData)
            if let thumb = document.thumbnailData,
               let img = UIImage(data: thumb) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 56, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .matchedGeometryEffect(id: "thumb-\(document.id)", in: animation)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(width: 56, height: 72)
                    .overlay(Image(systemName: document.documentType.systemImage).foregroundColor(.secondary))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(document.filename)
                    .font(.headline)
                    .lineLimit(2)
                Text(document.documentType.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let date = document.analysisResult?.documentDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
            ProcessingStatusBadge(status: document.processingStatus)
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

---

## Processing Status Component (PhaseAnimator)

```swift
struct ProcessingStatusBadge: View {
    let status: ProcessingStatus

    var body: some View {
        switch status {
        case .processing:
            PhaseAnimator([false, true], trigger: status) { isActive in
                HStack(spacing: 4) {
                    ProgressView().scaleEffect(0.7)
                    Text("Analyzing")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
                .opacity(isActive ? 1 : 0.6)
            } animation: { _ in .easeInOut(duration: 0.8) }

        case .complete:
            Label("Done", systemImage: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.green)
                .transition(.scale.combined(with: .opacity))

        case .failed:
            Label("Failed", systemImage: "exclamationmark.triangle.fill")
                .font(.caption2)
                .foregroundColor(.red)
        default:
            EmptyView()
        }
    }
}
```

---

## Streaming Chat Bubbles

```swift
struct ChatBubble: View {
    let message: ChatMessage
    let isStreaming: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(message.role == .user ? Color.blue : Color(.systemGray5))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    // Streaming cursor effect
                    .overlay(alignment: .bottomTrailing) {
                        if isStreaming {
                            RoundedRectangle(cornerRadius: 2)
                                .frame(width: 2, height: 14)
                                .foregroundColor(.primary.opacity(0.6))
                                .padding(.trailing, 14)
                                .padding(.bottom, 10)
                                .phaseAnimator([true, false]) { view, phase in
                                    view.opacity(phase ? 1 : 0)
                                } animation: { _ in .linear(duration: 0.5) }
                        }
                    }

                // Medical disclaimer for AI responses
                if message.role == .assistant && !isStreaming {
                    Text("Not medical advice. Consult your doctor.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
        .padding(.horizontal)
        .animation(.spring(duration: 0.3), value: message.content)
    }
}
```

**Streaming ViewModel pattern:**
```swift
@Observable @MainActor
class ChatViewModel {
    var messages: [ChatMessage] = []
    var streamingText = ""
    var isStreaming = false

    func sendMessage(_ query: String) async {
        isStreaming = true
        streamingText = ""
        messages.append(ChatMessage(role: .user, content: query))

        do {
            for try await chunk in chatService.streamChat(query: query, documentIDs: []) {
                streamingText += chunk
            }
            messages.append(ChatMessage(role: .assistant, content: streamingText))
        } catch { /* handle error */ }

        isStreaming = false
        streamingText = ""
    }
}
```

---

## Health Timeline

```swift
struct HealthTimelineView: View {
    let events: [HealthEvent]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    HStack(alignment: .top, spacing: 16) {
                        // Timeline spine
                        VStack(spacing: 0) {
                            Circle()
                                .fill(event.category.color)
                                .frame(width: 12, height: 12)
                                .padding(.top, 4)
                            if index < events.count - 1 {
                                Rectangle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                            }
                        }
                        .frame(width: 12)

                        // Event card
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title).font(.subheadline).bold()
                            Text(event.eventDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption).foregroundColor(.secondary)
                            if let summary = event.summary {
                                Text(summary).font(.caption).foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.bottom, 20)
                        Spacer()
                    }
                    .scrollTransition { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.5)
                            .offset(x: phase.isIdentity ? 0 : -8)
                    }
                }
            }
            .padding()
        }
    }
}

extension HealthEvent.EventCategory {
    var color: Color {
        switch self {
        case .diagnosis: return .red
        case .medication: return .blue
        case .lab: return .purple
        case .procedure: return .orange
        case .visit: return .green
        case .imaging: return .indigo
        case .insurance: return .gray
        }
    }
}
```

---

## Swift Charts (Lab Values, Health Data)

```swift
import Charts

// Abnormal lab values chart
Chart(labValues) { lab in
    BarMark(
        x: .value("Test", lab.name),
        y: .value("Value", lab.numericValue)
    )
    .foregroundStyle(lab.isAbnormal ? Color.red : Color.green)
    .annotation(position: .top) {
        if lab.isAbnormal {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.caption)
        }
    }
}
.chartXAxis {
    AxisMarks(values: .automatic) { _ in
        AxisValueLabel(orientation: .verticalReversed)
    }
}
.frame(height: 200)
```

**Use `SectorMark` (pie/donut) for document type breakdown, `LineMark` for vitals over time.**

---

## TipKit (Onboarding)

```swift
import TipKit

struct UploadFirstDocumentTip: Tip {
    var title: Text { Text("Add your first document") }
    var message: Text? { Text("Tap + to scan or import a medical record") }
    var image: Image? { Image(systemName: "doc.badge.plus") }
}

struct ConsentBeforeUploadTip: Tip {
    var title: Text { Text("Your data stays private") }
    var message: Text? { Text("All processing happens on your encrypted records. Nothing is shared without your permission.") }
}

// In DocumentLibraryView
struct DocumentLibraryView: View {
    private let uploadTip = UploadFirstDocumentTip()

    var body: some View {
        List { /* ... */ }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: showUpload) {
                        Image(systemName: "plus")
                    }
                    .popoverTip(uploadTip)
                }
            }
    }
}

// App init — configure before first view renders
@main
struct ChippyApp: App {
    init() {
        try? Tips.configure([
            .displayFrequency(.immediate),  // show immediately in dev
            .datastoreLocation(.applicationDefault)
        ])
    }
}
```

---

## Accessibility Rules for Health Data

```swift
// Always combine metric + unit for VoiceOver
HStack {
    Text("72").font(.title)
    Text("bpm").font(.caption)
}
.accessibilityElement(children: .combine)
.accessibilityLabel("Heart rate: 72 beats per minute")

// Abnormal values need emphasis
Text("HIGH")
    .accessibilityLabel("Abnormal: above reference range")

// Document card
DocumentCard(document: doc)
    .accessibilityLabel("\(doc.documentType.displayName) from \(doc.analysisResult?.documentDate?.formatted() ?? "unknown date")")
    .accessibilityHint("Double tap to view document details")

// Dynamic Type — always use system font styles, not fixed sizes
Text("Lab Result").font(.headline)  // scales automatically
// If custom size needed:
.font(.system(size: 16, weight: .semibold))
.dynamicTypeSize(.small ... .accessibility2)  // cap at accessibility2
```

**WCAG AA minimum for health data:** 4.5:1 contrast ratio for body text, 3:1 for large text (18pt+). Use system colors — they automatically meet this in both light/dark mode and high-contrast mode.

---

## iOS HIG Rules for Health Apps

- **Never display lab values without reference ranges** — a number without context is misleading
- **Always disclaim AI-generated explanations** — "This is for informational purposes only"
- **Don't replicate Apple Health's UI** — Apple will reject apps that look like Health.app
- **Consent before AI analysis** — show what will happen to their documents before the first upload
- **One destructive action per flow** — delete requires confirmation, never swipe-to-delete without undo/alert for health records
- **No in-app purchases on health features** — Apple scrutinizes paywalls on anything medical

---

## Libraries Worth Using

| Library | Purpose | Why |
|---------|---------|-----|
| **Swift Charts** (Apple native) | All data visualization | No dependency, fully accessible, Dark Mode |
| **QuickLook** (Apple native) | Document thumbnail + preview | Free, handles PDF/images natively |
| **TipKit** (Apple native, iOS 17+) | Onboarding tips | Zero overhead, system-consistent |
| **StoreKit 2** (Apple native) | Subscriptions/IAP | Native subscription UI |
| **ViewInspector** | Unit testing SwiftUI views | Essential for testing |

**Don't add:** Third-party chart libraries, third-party navigation frameworks, generic UI component packs — Apple's native frameworks cover everything Chippy needs.

---

## Connections

- [[wiki/healthrecords-ai-app/swift-ios-research]] — VisionKit, PDFKit, HealthKit, SwiftData deep dive
- [[wiki/healthrecords-ai-app/architecture]] — full app architecture and iOS project structure

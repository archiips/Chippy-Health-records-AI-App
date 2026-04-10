# Swift / iOS Research Notes

**Tags:** #swift #ios #visionkit #healthkit #swiftdata #swiftui
**Related:** [[wiki/healthrecords-ai-app/architecture]], [[wiki/healthrecords-ai-app/product-document]]
**Source:** Deep research — April 2026

---

## VisionKit — Document Scanning

- `VNDocumentCameraViewController` — iOS 13+, **physical device only** (simulator returns `isSupported == false`)
- Auto: perspective correction, edge detection, brightness/contrast, multi-page, user guidance overlays
- `scan.pageCount` + `scan.imageOfPage(at:)` for multi-page access
- **Cannot** set max page count, customize UI strings, or control image resolution
- Use `UIViewControllerRepresentable` to wrap for SwiftUI
- **Info.plist required:** `NSCameraUsageDescription`
- Run `VNRecognizeTextRequest` on scanned images for on-device OCR before upload

## PDFKit — Text Extraction

- `PDFPage.string` → plain text (works only for text-based PDFs, not scanned)
- `PDFPage.attributedString` → styled text (useful for table structure hints)
- **Scanned PDFs have no text layer** — must run Vision OCR separately
- iOS 19 / Live Text: PDFKit now integrates Live Text OCR for scanned PDFs automatically in PDFView

### When to Use Native vs Server-Side Extraction

| | Native (PDFKit + Vision) | Server-Side (Textract/Azure DI) |
|--|--------------------------|--------------------------------|
| Cost | Free | $1.50–$15 / 1000 pages |
| Privacy | On-device | Data leaves device |
| Printed text | Good | Excellent |
| Handwritten | Poor | Good |
| Tables/structured | Poor | Excellent |

**Strategy:** Native Vision OCR as primary, server-side fallback for complex structured docs

## HealthKit

### Clinical Records (FHIR R4)
- `.labResultRecord`, `.conditionRecord`, `.medicationRecord`, `.vitalSignRecord`, `.allergyRecord`, `.procedureRecord`, `.immunizationRecord`, `.clinicalNoteRecord`
- Data is real FHIR R4 JSON from hospitals connected via Apple Health Records (SMART on FHIR)
- **New (iOS 19):** Medications API with per-object authorization
- **Cannot query if user denied access** — returns `.notDetermined` always (privacy)
- **Cannot write clinical records** — read-only
- Entitlement: `com.apple.developer.healthkit.access` + `health-records` value
- **`health-records` requires additional Apple approval** beyond standard HealthKit

### Key Library
Stanford **HealthKitOnFHIR** Swift Package — pre-built Codable models for all FHIR R4 types. Use this instead of rolling your own parsers.

## SwiftUI Patterns

### Chat Interface (Streaming)
- Use `@Observable` ViewModel on `@MainActor`
- Append placeholder assistant message → update `.content` as chunks arrive
- `ScrollViewReader` + `.onChange(of: messages.count)` for auto-scroll
- `URLSession.shared.bytes(for: request)` → `bytes.lines` for SSE parsing (no third-party libs needed)

### Async Processing Pattern
- `Task.detached(priority: .userInitiated)` for CPU-intensive OCR off main thread
- `withThrowingTaskGroup` for concurrent multi-page OCR
- `AsyncThrowingStream` for pipeline progress updates to UI
- `@Observable` + `@MainActor` = automatic UI refresh when state changes

## Swift + FastAPI Integration

### Multipart PDF Upload
- Use `URLSession` with `Data` body — no Alamofire needed
- `asCopy: true` in `UIDocumentPickerViewController` → file copied to sandbox, no security-scoped URL complexity

### SSE Streaming
- `URLSession.shared.bytes(for: request)` → `bytes.lines` async sequence
- Parse `data: {...}\n\n` format manually — simple, no third-party needed
- Yields chunks directly into `AsyncThrowingStream` for consumption in ViewModel

### JWT Auth
- Store in Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` (prevents iCloud Keychain sync)
- Implement refresh token rotation in `AuthManager` using async/await
- Inject `Authorization: Bearer {token}` via centralized `authenticatedRequest()` method

## Local Storage

### SwiftData (iOS 17+) — Recommended
- `@Model` macro, native SwiftUI integration, `VersionedSchema` for migrations
- Set `NSFileProtectionComplete` on the SQLite store file after creation
- **`cloudKitDatabase: .none`** — Apple explicitly prohibits storing personal health data in iCloud

### What Goes Where
| Data | Storage |
|------|---------|
| JWT tokens, encryption keys | Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) |
| Document metadata, analysis | SwiftData with `NSFileProtectionComplete` |
| PDF files | `FileManager` in `applicationSupportDirectory` with `FileProtectionType.complete` |
| HealthKit-sourced data | Do NOT persist — re-query HealthKit each session |
| User preferences | UserDefaults (non-sensitive only) |

## App Architecture

### MVVM + Async/Await
- `@Observable` ViewModels on `@MainActor` — UI updates always on main thread
- `actor` for service layer — thread-safe network calls
- Dependency injection via `EnvironmentValues` — testable, clean

### Recommended Layer Structure
```
Features/ (screen-level ViewModels + Views)
Services/ (API clients, HealthKit, DocumentProcessor — all actors)
Persistence/ (SwiftData stack + repository layer)
Core/ (AuthManager, Keychain, AppLock, Extensions)
```

## iOS Health App — App Store Requirements

- Privacy policy mandatory for any HealthKit use
- Third-party AI disclosure required — must show consent before first analysis
- Health data **cannot** be used for advertising (non-negotiable)
- Health data **cannot** be synced to iCloud
- `health-records` entitlement — must justify in App Review notes
- Face ID / Touch ID app lock strongly recommended (users expect it for health data)

## Face ID App Lock Pattern
```swift
// LocalAuthentication framework
// evaluatePolicy(.deviceOwnerAuthentication, ...) — covers Face ID + passcode fallback
// Show lock screen on app foreground, authenticate on demand
```

## Minimum Target
- **iOS 17** for `@Observable` + `SwiftData` + `scrollPosition`
- Covers ~85% of active devices as of 2026

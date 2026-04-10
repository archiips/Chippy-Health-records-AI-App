# Chippy — Todo

> 8-week MVP build. 4 sprints. Tasks are ordered by dependency — work top to bottom within each sprint.

## Format

```
- [ ] **Pending task**
  - [ ] Subtask

- [x] **Completed task**
  ✅ Completed: 2026-04-07
  - [x] Subtask

- [ ] **In-progress task**
  ⚠️ Partially Completed: 2026-04-07
  - [x] Done subtask
  - [ ] Remaining subtask

- [ ] **Blocked task**
  🚧 Blocked: 2026-04-07 — reason here
```

---

---

## Sprint 1 — Weeks 1–2: Auth, Supabase Schema, iOS Project + Upload

### Backend

- [x] **Set up FastAPI project**
  ✅ Completed: 2026-04-07
  - [x] Create project directory structure: `backend/app/{api,services,ai,models,core,background}`
  - [x] Initialize `pyproject.toml` with dependencies: fastapi, uvicorn, pydantic, supabase-py, python-jose, passlib[bcrypt], python-multipart, pymupdf, llama-index, llama-index-llms-google-genai, llama-index-embeddings-google-genai, qdrant-client, chromadb
  - [x] Create `app/main.py` with FastAPI app instance, CORS middleware, and router registration
  - [x] Create `.env.example` with all required env vars (GOOGLE_API_KEY, SUPABASE_URL, SUPABASE_SERVICE_KEY, SUPABASE_ANON_KEY, QDRANT_URL, QDRANT_API_KEY, JWT_SECRET_KEY, JWT_ALGORITHM, ENV)
  - [x] Create `app/core/config.py` with Pydantic Settings loading from `.env`
  - [x] Add `Dockerfile` and `docker-compose.yml` (app + optional local Qdrant)

- [x] **Supabase schema + RLS**
  ✅ Completed: 2026-04-07
  - [x] Create `documents` table
  - [x] Create `analysis_results` table — added `explainer_text` column for caching LLM responses
  - [x] Create `health_events` table
  - [x] Create `chat_messages` table
  - [x] Enable RLS on all four tables
  - [x] Write + apply RLS policies for each table via MCP
  - [x] Apply storage RLS policies via MCP
  - [x] Create `medical-documents` storage bucket (private)

- [x] **JWT auth (FastAPI)**
  ✅ Completed: 2026-04-07 — stateless JWT pair (no denylist, post-MVP); Supabase Auth handles user storage
  - [x] Create `app/core/security.py`: bcrypt hashing
  - [x] Create `app/core/auth.py`: JWT creation/decode, `get_current_user` dependency
  - [x] Create `app/core/supabase_client.py`: service-role singleton
  - [x] `POST /auth/register`
  - [x] `POST /auth/login`
  - [x] `POST /auth/refresh`
  - [x] `POST /auth/logout`
  - [ ] Test endpoints — run server first (`pip install -e . && uvicorn app.main:app --reload`)

- [x] **Document upload endpoint**
  ✅ Completed: 2026-04-07 — includes retry endpoint; ingestion stub flips status to complete (real pipeline Sprint 2)
  - [x] Create `app/api/documents.py` router
  - [x] `POST /documents/upload`
  - [x] `GET /documents`
  - [x] `GET /documents/{id}`
  - [x] `DELETE /documents/{id}`
  - [x] `GET /documents/{id}/url`
  - [x] `POST /documents/{id}/retry`

---

### iOS

- [x] **Xcode project setup**
  ✅ Completed: 2026-04-07 — all Swift source files + directory structure created; Xcode project creation + Info.plist keys require 3 manual steps (see below)
  - [ ] Create new Xcode project: SwiftUI, iOS 17 minimum deployment target, bundle ID `com.chippy.app` — **manual step in Xcode**
  - [x] Add SwiftData capability — enabled via `AppModelContainer` + entitlements
  - [x] Configure project directory structure: `App/`, `Features/`, `Services/`, `Persistence/`, `Core/`
  - [x] Add `.gitignore` (exclude `*.xcuserdata`, `DerivedData`, `.DS_Store`)
  - [x] Set `NSFileProtectionComplete` as default data protection in entitlements — `Chippy.entitlements`
  - [ ] Add `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` to `Info.plist` — **manual step in Xcode**
  - [ ] Configure App Transport Security (require HTTPS) — **manual step in Xcode**

- [x] **SwiftData stack**
  ✅ Completed: 2026-04-07
  - [x] Define `HealthDocument` model: `id`, `filename`, `fileURL`, `documentType`, `processingStatus`, `thumbnailData`, `ocrText`, `uploadedAt`, `analysisResult` (optional relationship)
  - [x] Define `AnalysisResult` model: `id`, `documentId`, `summary`, `documentDate`, `providerName`, `diagnoses`, `medications`, `labValues`, `keyFindings` (JSONB → `[LabValue]` serialized as Data)
  - [x] Define `HealthEvent` model: `id`, `documentId`, `title`, `category` (enum), `eventDate`, `summary`
  - [x] Define `ChatMessage` model: `id`, `role` (enum), `content`, `sourceDocumentIds`, `createdAt`
  - [x] Configure `ModelContainer` in `App/ChippyApp.swift` with `cloudKitDatabase: .none`
  - [x] Create `Persistence/DocumentRepository.swift`: `insert`, `fetchAll`, `fetchById`, `delete`

- [x] **Keychain + auth services**
  ✅ Completed: 2026-04-07 — also created APIClient actor (needed by AuthService and future DocumentService)
  - [x] Create `Core/KeychainService.swift`: `save(token:forKey:)`, `load(key:)`, `delete(key:)` using `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
  - [x] Create `Core/AuthManager.swift` (`@Observable @MainActor`): holds `isAuthenticated`, `accessToken`, `currentUserId`; handles token refresh on expiry
  - [x] Create `Services/AuthService.swift` (`actor`): `register(email:password:)`, `login(email:password:)`, `refreshToken()`, `logout()`
  - [x] Inject `AuthManager` via `@Environment` in root view

- [x] **Auth UI**
  ✅ Completed: 2026-04-07
  - [x] Create `Features/Onboarding/AuthView.swift`: toggle between Sign In / Sign Up
  - [x] `LoginView`: email + password fields, login button, error display
  - [x] `SignUpView`: email + password + confirm password, validation, sign up button
  - [x] Show `AuthView` when `!authManager.isAuthenticated`, `MainTabView` otherwise
  - [x] Dismiss keyboard on tap outside text fields — `scrollDismissesKeyboard(.interactively)` + `@FocusState`

- [x] **Document import UI**
  ✅ Completed: 2026-04-07 — also created DocumentService actor and added multipart upload to APIClient
  - [x] Create `Features/DocumentImport/DocumentScannerView.swift` wrapping `VNDocumentCameraViewController` in `UIViewControllerRepresentable`
  - [x] Create `Features/DocumentImport/FilePicker.swift` wrapping `UIDocumentPickerViewController` (PDF only)
  - [x] Create `Features/DocumentImport/PhotoPicker.swift` using `PHPickerViewController` (JPEG/PNG/HEIC)
  - [x] Create `Features/DocumentImport/DocumentImportViewModel.swift` (`@Observable @MainActor`):
    - [x] On scan complete: save scanned image as PDF to `applicationSupportDirectory` with `FileProtectionType.complete`
    - [x] Run `VNRecognizeTextRequest` on-device to extract OCR text
    - [x] Generate thumbnail via `QLThumbnailGenerator`, cache in SwiftData as `Data`
    - [x] Call `DocumentService.upload(fileURL:ocrText:)`, update status in SwiftData
  - [x] Create import bottom sheet with three options: Scan, Files, Photos
  - [x] Show upload progress indicator (indeterminate) while uploading
  - [x] Handle errors: show alert with retry option

- [x] **Document library (basic)**
  ✅ Completed: 2026-04-07
  - [x] Create `Features/DocumentLibrary/DocumentLibraryView.swift` using `List` (not `LazyVStack`)
  - [x] Embed in `NavigationStack` (via `MainTabView`)
  - [x] Add toolbar `+` button → import `confirmationDialog` source picker
  - [x] Poll document status every 5 sec for documents with `status == .processing` (cancel on view disappear)
  - [x] `DocumentCard` component: thumbnail (56×72, `RoundedRectangle(cornerRadius: 6)`), filename, document type, date, `ProcessingStatusBadge`
  - [x] `ProcessingStatusBadge`: `PhaseAnimator` pulse for `.processing`, green checkmark for `.complete`, red triangle for `.failed`
  - [x] Swipe-to-delete with confirmation alert (never silent delete)

---

## Sprint 2 — Weeks 3–4: Document Pipeline (Extract → Embed → Qdrant)

### Backend

- [x] **Document ingestion background task**
  ✅ **Completed:** 2026-04-07 — extraction inline in pipeline.py (no separate extraction_service.py needed); Gemini 2.5 Flash used for both classification and extraction
  - [x] Create `app/background/tasks.py` with `ingest_document(document_id, user_id)` async function
  - [x] Download file from Supabase Storage into memory (do not write to disk on server)
  - [x] Extract text with PyMuPDF (`fitz`): `doc = fitz.open(stream=bytes, filetype="pdf")`, iterate pages, extract text blocks
  - [x] Merge with OCR text from `documents.ocr_text` (use server-extracted text as primary if richer, OCR as fallback)
  - [x] Classify document type using Gemini 2.5 Flash — prompt returns one of: `lab_result | radiology | discharge_summary | clinical_note | prescription | insurance | other`
  - [x] Update `documents.document_type` and `documents.status = 'processing'`

- [x] **LlamaIndex chunking (type-aware)**
  ✅ **Completed:** 2026-04-07
  - [x] Create `app/ai/chunking.py`
  - [x] `chunk_document(text, doc_type, embed_model)` factory function:
    - [x] `lab_result` → `SentenceSplitter(chunk_size=256, chunk_overlap=20)`
    - [x] `radiology` → `SemanticSplitterNodeParser(embed_model=embed_model)`
    - [x] `discharge_summary`, `clinical_note` → `SentenceWindowNodeParser(window_size=3)`
    - [x] `insurance`, `other` → `SentenceSplitter(chunk_size=512, chunk_overlap=50)`
  - [x] Add metadata to each node: `user_id`, `document_id`, `document_type`, `page_number`
  - [x] Return list of `TextNode` objects

- [x] **Embedding + Qdrant indexing**
  ✅ **Completed:** 2026-04-07 — `app/ai/vector_store.py` handles both Chroma (dev) and Qdrant (prod); Gemini/embed model lazy-initialized to avoid import-time failure
  - [x] Create `app/ai/pipeline.py` with full ingestion pipeline
  - [x] Initialize Gemini `text-embedding-004` embed model (lazy init)
  - [x] Create/verify Qdrant collection `medical_records` (run once on startup)
  - [x] Embed nodes via `get_text_embedding_batch`
  - [x] Upsert vectors with payload: `{user_id, document_id, document_type}`
  - [x] Dev path: local Chroma (`ENV=development`), prod path: Qdrant Cloud (`ENV=production`)

- [x] **Gemini structured extraction**
  ✅ **Completed:** 2026-04-07 — extraction handled inline in pipeline.py `_extract_structured()`; JSON response with `response_mime_type="application/json"`
  - [x] Create `app/ai/prompts.py` with `EXTRACTION_SYSTEM_PROMPT` and `CLASSIFICATION_PROMPT`
  - [x] Call `gemini-2.5-flash` with document text + extraction prompt
  - [x] Parse JSON response, insert into `analysis_results` table
  - [x] Generate `health_events` rows from extraction

- [x] **Wire up background task**
  ✅ **Completed:** 2026-04-07
  - [x] In `POST /documents/upload`: call `BackgroundTasks.add_task(ingest_document, document_id, user_id)`
  - [x] Update `documents.status` to `complete` or `failed` at end of ingestion
  - [x] `GET /documents/{id}/status` endpoint — returns status, document_type, error_message
  - [x] Add startup event in `main.py`: ping Qdrant on startup to prevent inactivity suspension

- [x] **Error handling + retry**
  ✅ **Completed:** 2026-04-07
  - [x] Wrap entire ingestion pipeline in try/except, set `status = 'failed'` with `error_message` on any unhandled exception
  - [x] Log structured errors (include `document_id`, `user_id`, exception type)
  - [x] `POST /documents/{id}/retry` endpoint — re-enqueues ingestion for failed documents

---

### iOS

- [x] **API client**
  ✅ **Completed:** 2026-04-07 — built in Sprint 1; extended in Sprint 2 with `pollStatus`, `retry`, `fetchDocumentWithAnalysis`
  - [x] Create `Services/APIClient.swift` (`actor`): base URL from config, Bearer token header, JSON decode
  - [x] Create `Services/DocumentService.swift` (`actor`): `upload`, `fetchDocuments`, `fetchDocumentWithAnalysis`, `pollStatus`, `deleteDocument`, `retry`

- [x] **Document library — full implementation**
  ✅ **Completed:** 2026-04-07 — filter/sort as toolbar menus; analysis results synced from backend when status → complete; retry swipe action added
  - [x] Fetch documents from backend on view appear, sync analysis results into SwiftData
  - [x] Filter toolbar: Menu for document type (All | Lab | Radiology | Discharge | Prescription | Insurance | Other)
  - [x] Sort by: newest first (default), oldest first
  - [x] Empty state: contextual per filter ("No Lab Results" vs "No Documents")
  - [x] Pull-to-refresh
  - [x] Optimistic UI: show document card immediately after scan/import with `.processing` status, update when backend responds

- [x] **Document detail view**
  ✅ **Completed:** 2026-04-07 — "Explain this" button present but disabled (Sprint 3); ShareLink used instead of UIActivityViewController; lab values always show reference range (or "Not available")
  - [x] Create `Features/DocumentDetail/DocumentDetailView.swift`
  - [x] Show original document via `QuickLook` (`QLPreviewController` wrapped in `UIViewControllerRepresentable`)
  - [x] Show AI summary, diagnoses, medications, key findings in sections
  - [x] Lab values table: name | value | reference range | abnormal badge
  - [x] "Explain this" button → disabled placeholder (Sprint 3)
  - [x] Share button → `ShareLink` (modern SwiftUI equivalent of UIActivityViewController)
  - [x] Accessible: `DocumentCard` VoiceOver label includes type, filename, date, status; hint = "Double tap to view"

---

## Sprint 3 — Weeks 5–6: RAG Chat + Document Explainer + SSE Streaming

### Backend

- [x] **RAG query engine**
  ✅ **Completed:** 2026-04-08 — direct Gemini streaming used instead of LlamaIndex LLM wrapper; retriever top-k=5 with user_id filter; MockEmbedding used for retrieval-only index
  - [x] Create `app/ai/query_engine.py`:
    - [x] Build `VectorStoreIndex` from Qdrant collection filtered by `user_id`
    - [x] Configure retriever: top-k=5, MMR reranking enabled
    - [x] System prompt: ground responses strictly in retrieved chunks, refuse questions requiring external medical knowledge, always cite source `document_id`s
  - [x] Create `app/services/chat_service.py`:
    - [x] `stream_chat(query, user_id, document_ids=None)` — async generator yielding text chunks
    - [x] Optionally filter retrieval to specific `document_ids` (for document-scoped Q&A)
    - [x] Persist user message + assistant message to `chat_messages` table after streaming completes

- [x] **SSE streaming chat endpoint**
  ✅ **Completed:** 2026-04-08
  - [x] Create `app/api/chat.py` router
  - [x] `POST /chat/stream` — accepts `{query: str, document_ids: list[str] | None}`, returns `StreamingResponse` with `media_type="text/event-stream"`
  - [x] Format: `data: {chunk}\n\n`, end with `data: [DONE]\n\n`
  - [x] Handle client disconnect (check `await request.is_disconnected()` in stream loop)
  - [x] `GET /chat/history` — return last 50 messages for user, ordered by `created_at`
  - [x] `DELETE /chat/history` — clear all chat messages for user

- [x] **Document explainer endpoint**
  ✅ **Completed:** 2026-04-08 — cached in `analysis_results.explainer_text`; streams from cache on repeat calls
  - [x] `POST /documents/{id}/explain` — fetch analysis result + full text, call Gemini 2.5 Flash with `EXPLAINER_PROMPT` (plain-language explanation, define medical terms inline, "what does this mean for me?" section), stream response via SSE
  - [x] Write `EXPLAINER_PROMPT` in `app/ai/prompts.py`: instruct model to explain in simple language a non-medical person can understand, define jargon inline, end with "This is for informational purposes only. Consult your doctor."
  - [x] Cache explainer result in `analysis_results.explainer_text` (don't re-call LLM if already cached)

---

### iOS

- [x] **SSE streaming client**
  ✅ **Completed:** 2026-04-08
  - [x] Create `Services/StreamingService.swift` (`actor`):
    - [x] Use `URLSession.shared.bytes(for:request)` → `bytes.lines` async sequence
    - [x] Parse `data: {chunk}` SSE format, emit chunks via `AsyncStream<String>`
    - [x] Handle `[DONE]` sentinel to close stream
    - [x] Cancel on task cancellation

- [x] **Chat view**
  ✅ **Completed:** 2026-04-08 — "Select documents" filter chip deferred to Sprint 4 polish; ChatBubble in same file (private struct)
  - [x] Create `Features/Chat/ChatView.swift`
  - [x] `ChatViewModel` (`@Observable @MainActor`): `messages: [ChatMessage]`, `streamingText: String`, `isStreaming: Bool`
  - [x] `sendMessage(_:)`: append user message, set `isStreaming = true`, stream chunks into `streamingText`, append final assistant message, set `isStreaming = false`
  - [x] `ChatBubble` component:
    - [x] User bubble: right-aligned, blue background, white text
    - [x] Assistant bubble: left-aligned, `systemGray5` background, primary text
    - [x] Streaming cursor: blinking `RoundedRectangle(width:2, height:14)` via `PhaseAnimator([true,false])` with `.linear(duration:0.5)`
    - [x] Medical disclaimer below completed assistant messages: "Not medical advice. Consult your doctor." in `.caption2`
    - [x] Animate new bubbles in with `.spring(duration:0.3)`
  - [x] `ScrollViewReader` auto-scroll to latest message as chunks arrive
  - [x] Input bar: `TextField` + send `Button`, disable send while streaming, character limit 2000
  - [x] Show suggested starter questions when `messages.isEmpty`: "What medications am I on?", "When was my last lab work?", "Summarize my recent visits"
  - [ ] "Select documents" filter chip — deferred to Sprint 4 polish
  - [x] Accessible: assistant bubble VoiceOver reads full message after stream completes

- [x] **Document explainer view**
  ✅ **Completed:** 2026-04-08 — "Medical terms" expandable section deferred (requires complex markdown parsing); share via ShareLink
  - [x] Create `Features/DocumentDetail/ExplainerView.swift`
  - [x] Stream explanation text into `Text` view as chunks arrive (update a `@State var text` string)
  - [x] Show blinking cursor at end of text during streaming (same `PhaseAnimator` pattern)
  - [ ] "Medical terms" expandable section — deferred (requires markdown bold parsing)
  - [x] Share button: copy explanation text to clipboard or share as plain text
  - [x] Prominent disclaimer banner at top: "For informational purposes only. Not a substitute for professional medical advice."

- [x] **Tab bar + navigation**
  ✅ **Completed:** 2026-04-08
  - [x] Create `App/MainTabView.swift` with 4 tabs: Library, Timeline, Chat, Settings
  - [x] Create `AppCoordinator` (`@Observable @MainActor`) with `NavigationPath` and `Route` enum: `.documentDetail(HealthDocument)`
  - [x] Inject coordinator via `@Environment`
  - [x] One `NavigationStack` per tab — each maintains independent history

---

## Sprint 4 — Weeks 7–8: Timeline, Face ID, Onboarding, TestFlight

### Backend

- [ ] **Upgrade pipeline to gemini-2.5-flash**
  - [ ] Change `_FLASH_MODEL` in `pipeline.py` from `gemini-1.5-flash` back to `gemini-2.5-flash`
  - [ ] Change `_MODEL` in `gemini_client.py` from `gemini-1.5-flash` to `gemini-2.5-flash`
  - [ ] Requires billing-enabled Google Cloud project (free tier only allows 20 req/day on 2.5-flash)

- [x] **Timeline API**
  ✅ **Completed:** 2026-04-08
  - [x] `GET /timeline` — return all `health_events` for user ordered by `event_date DESC`, with optional `category` filter and `from/to` date range params
  - [x] `GET /timeline/{event_id}` — return single event with linked `document_id`
  - [x] Ensure events are generated correctly during ingestion (Sprint 2) — QA edge cases: documents with no date, documents with multiple event types

---

### iOS

- [x] **Health timeline view**
  ✅ **Completed:** 2026-04-08 — TimelineService fetches from API; SwiftData HealthEvent not used for display (API-driven); TipKit deferred
  - [x] Create `Features/Timeline/HealthTimelineView.swift`
  - [x] Use `LazyVStack` (not `List`) — needed for `scrollTransition` scroll animations
  - [x] Timeline spine: `Circle` (12pt, category color) + `Rectangle` connector between events
  - [x] `.scrollTransition` effect: `opacity(phase.isIdentity ? 1 : 0.5)`, `offset(x: phase.isIdentity ? 0 : -8)`
  - [x] Category color map: diagnosis=red, medication=blue, lab=purple, procedure=orange, visit=green, imaging=indigo, insurance=gray
  - [x] Filter bar (horizontal scroll): All | Diagnosis | Medication | Lab | Procedure | Visit | Imaging
  - [x] Date range filter: segmented control (3M / 6M / 1Y / All)
  - [x] Tap event row → push `DocumentDetailView` for linked document
  - [x] Empty state per filter: "No {category} events found"
  - [x] Section headers pinned by date (month/year grouping)

- [x] **Face ID / Touch ID app lock**
  ✅ **Completed:** 2026-04-08 — falls back to device passcode; lock on background, re-auth on active
  - [x] Create `Core/AppLockManager.swift` (`@Observable @MainActor`) using `LocalAuthentication`
  - [x] `authenticate()`: uses `.deviceOwnerAuthentication` (covers both biometrics + passcode fallback)
  - [x] Track `isUnlocked: Bool` — `LockScreenView` shown when false
  - [x] Lock on `scenePhase == .background`
  - [x] Re-authenticate on `scenePhase == .active` if locked
  - [x] `LockScreenView`: Chippy logo + biometric unlock button
  - [x] Allow fallback to device passcode

- [x] **Onboarding flow**
  ✅ **Completed:** 2026-04-08 — 3 screens (Welcome, Privacy, How it works); TipKit deferred for personal project
  - [x] Create `Features/Onboarding/OnboardingView.swift` (shown only on first launch)
  - [x] Screen 1 — Welcome: app name, tagline
  - [x] Screen 2 — Privacy: "Your data stays private"
  - [x] Screen 3 — How it works: upload + ask questions
  - [x] Persist onboarding completion in `UserDefaults` (`hasCompletedOnboarding`)

- [x] **Settings view**
  ✅ **Completed:** 2026-04-08 — "Change Passcode" omitted (personal project); faceIDEnabled wired into AppLockManager; sign-out removed from DocumentLibraryView toolbar
  - [x] Create `Features/Settings/SettingsView.swift`
  - [x] Account section: email display, sign out button (with confirmation)
  - [x] Security section: toggle Face ID on/off (AppLockManager respects faceIDEnabled AppStorage)
  - [x] Data section: "Delete all my data" — confirm alert → call `DELETE /account` endpoint, clear SwiftData + Keychain, sign out
  - [x] About section: app version, "Not medical advice" statement

- [ ] **App polish**
  ⚠️ **Partially Completed:** 2026-04-09 — app icon requires design asset; VoiceOver audit requires physical device
  - [ ] App icon (all required sizes): 1024×1024 base + Xcode asset catalog auto-generates rest — needs design asset
  - [x] Launch screen: auto-generated via `INFOPLIST_KEY_UILaunchScreen_Generation = YES` in build settings
  - [x] Accent color: teal-blue set in `AccentColor.colorset` with light/dark variants
  - [x] Empty states: `ContentUnavailableView` on library, timeline (per-filter), chat — all covered
  - [x] Loading states: `SkeletonView` + `SkeletonRow` components; skeleton on library + timeline initial load
  - [x] Error states: inline error banners in timeline list and chat input bar (replaced blocking alerts)
  - [x] Haptic feedback: `.light` impact on chat send, `.success` on chat response complete + upload complete
  - [x] Dynamic Type: all text uses system font styles throughout (`.subheadline`, `.caption`, `.body`, etc.)
  - [ ] VoiceOver audit: test core flows with VoiceOver on device — manual testing required
  - [x] Dark mode: system colors used throughout (`Color(.secondarySystemBackground)`, `.systemGray5`, etc.)
  - [x] Portrait-only on iPhone: locked to `UIInterfaceOrientationPortrait` in build settings
  - [x] Camera + photo library usage descriptions added to build settings (required for scanner/photos)

- [ ] **TestFlight prep**
  - [ ] Set up App Store Connect app record (bundle ID, name, privacy policy URL)
  - [ ] Configure signing: distribution certificate + provisioning profile
  - [ ] Archive and upload build via Xcode Organizer
  - [ ] Fill in TestFlight metadata: test notes, what to test, known issues
  - [ ] Submit for Beta App Review (required for external testers)
  - [ ] Add 5–10 internal testers first, gather feedback before external group
  - [ ] Crash reporting: enable Xcode Organizer crash logs + add `MetricKit` for hang/crash reporting

---

## Backlog (Post-MVP — v2+)

- [ ] **F8: Appointment Prep** — AI-generated question list for upcoming appointment based on recent records
- [ ] **F9: HealthKit Integration** — FHIR clinical records pull, vitals overlay on timeline
- [ ] **F10: Pattern & Gap Detection** — "You haven't had a cholesterol panel in 3 years", trending alerts
- [ ] **F11: Medication Reconciliation** — synthesized current med list, flag discrepancies across providers
- [ ] **Celery + Redis** — replace FastAPI BackgroundTasks with proper task queue before real users
- [ ] **Claude Sonnet 4.6 chat upgrade** — paid tier: route chat to Claude when user upgrades to Pro
- [ ] **StoreKit 2 subscriptions** — Free / Pro ($12.99/mo) / Annual ($99/yr) via `StoreKit 2`
- [ ] **Qdrant production migration** — verify single-collection `is_tenant=True` setup holds at scale
- [ ] **HIPAA upgrade path** — Vertex AI (Gemini + Claude), Supabase Team + HIPAA add-on
- [ ] **Provider summary PDF export** — generate shareable PDF summary for doctor appointments

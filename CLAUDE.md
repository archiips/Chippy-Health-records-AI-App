# Chippy — Health Records AI App

*Your health history, finally clear.*

An iOS app that turns confusing medical documents into a searchable health timeline explained in plain language by AI.

---

## Project Overview

- **App Name:** Chippy
- **Platform:** iOS (Swift + SwiftUI), iOS 17 minimum
- **Backend:** FastAPI (Python)
- **AI:** LlamaIndex orchestration, Gemini 2.5 Flash (primary), Claude Sonnet 4.6 (paid chat upgrade)
- **Database:** Supabase (Postgres + Storage + Auth)
- **Vector DB:** Chroma (dev/local) → Qdrant Cloud (prod)
- **Status:** Planning — 8-week MVP build

### Core User Flow
1. Scan/import medical documents (VisionKit, PDFKit, Photos)
2. On-device OCR (Vision framework) before upload
3. Backend ingestion: PyMuPDF extraction → LlamaIndex chunking → Qdrant embeddings + Gemini structured extraction
4. User-facing features: document library, health timeline, AI chat (RAG over their records), document explainer

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| iOS Frontend | Swift + SwiftUI + SwiftData (`@Observable`, `@MainActor`) |
| Document Scan | VisionKit (`VNDocumentCameraViewController`) |
| PDF Handling | PDFKit + Vision OCR (`VNRecognizeTextRequest`) |
| Health Data | HealthKit FHIR (v2 only) |
| Backend | FastAPI (Python 3.11+) |
| AI Orchestration | LlamaIndex |
| LLM (extraction) | Gemini 2.5 Flash |
| LLM (chat Q&A) | Gemini 2.5 Flash (free) → Claude Sonnet 4.6 (paid) |
| Embeddings | `text-embedding-004` (free, 1,500/day) or BGE-large-en-v1.5 (self-hosted) |
| Vector DB | Chroma (dev) → Qdrant Cloud (prod) |
| Database | Supabase (Postgres) |
| File Storage | Supabase Storage |
| Auth | Supabase Auth + JWT (FastAPI validates) |

---

## Architecture Decisions (Non-Negotiable)

### Qdrant: Single Collection, NOT per-user
Use payload-based tenant isolation with `is_tenant=True` on `user_id`. Per-user collections break at scale.
```python
# CORRECT
collection_name="medical_records"
filters={"user_id": user_id}  # always filter by user_id

# WRONG — do not do this
collection_name=f"user_{user_id}"
```

### Background Jobs: FastAPI BackgroundTasks for MVP, Celery for prod
Document ingestion takes 30–120 sec. Running in the web process degrades API latency for all users. Migrate to Celery + Redis before launch with real users.

### iOS Data Storage Rules
| Data | Where |
|------|-------|
| JWT tokens, keys | Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) |
| Document metadata, analysis | SwiftData with `NSFileProtectionComplete` |
| PDF files | `FileManager` in `applicationSupportDirectory` with `FileProtectionType.complete` |
| HealthKit data | Never persist — re-query each session |
| Anything sensitive | Never UserDefaults, never iCloud |

### SwiftData Config
```swift
// Always set cloudKitDatabase: .none — Apple prohibits health data in iCloud
ModelConfiguration(cloudKitDatabase: .none)
```

---

## Critical Gotchas

1. **Gemini 2.0 Flash is deprecated as of June 2026.** Always use `gemini-2.5-flash`, `gemini-2.5-pro`, or `gemini-2.5-flash-lite`. Never reference 2.0.

2. **AI Studio free tier may use data for Google model training.** Fine for dev with synthetic data. Never use with real patient health records. For real data: billing-enabled Google AI API or Vertex AI.

3. **VisionKit requires a physical device.** `VNDocumentCameraViewController.isSupported == false` on the simulator. Always run document scanner features on device.

4. **HealthKit `health-records` entitlement requires additional Apple approval** beyond standard HealthKit. v1 MVP does NOT require HealthKit — that's v2.

5. **Supabase RLS is mandatory.** Every table must have Row Level Security enabled. Users may only access their own rows. This must be enforced at the DB level, not just the API level.

6. **LlamaIndex import paths:** Use `llama_index.embeddings.google_genai` (not deprecated `GeminiEmbedding`).
   ```python
   from llama_index.embeddings.google_genai import GoogleGenAIEmbedding  # correct
   from llama_index.llms.google_genai import GoogleGenAI                 # correct
   ```

7. **Gemini native PDF upload files expire after 48 hours.** Always store originals in Supabase Storage. Never rely on Gemini File API as your storage layer.

8. **Claude Sonnet 4.6 has flat pricing across the full 1M context window.** No price cliff at 200K tokens unlike Gemini 2.5 Pro. Use Claude for full-context appointment prep queries, RAG chat with long histories.

---

## AI Model Routing

| Task | Free Tier | Paid |
|------|-----------|------|
| Document extraction | Gemini 2.5 Flash | Gemini 2.5 Flash (billing enabled) |
| Chat Q&A | Gemini 2.5 Flash | Claude Sonnet 4.6 |
| Radiology / multimodal | Gemini 2.5 Flash | Gemini 2.5 Pro |
| Background classification | Gemini 2.5 Flash-Lite | Same |
| Embeddings | `text-embedding-004` | Same (paid tier) |

---

## Chunking Strategy (Document-Type-Aware)

Research shows 87% retrieval accuracy with type-aware chunking vs 50% with fixed chunking on clinical documents.

| Document Type | Parser | Chunk Size | Rationale |
|--------------|--------|-----------|-----------|
| Lab results | `SentenceSplitter` | 256 tokens, 20 overlap | Keep analyte + value + range together |
| Radiology | `SemanticSplitterNodeParser` | Adaptive | Preserve FINDINGS/IMPRESSION sections |
| Discharge summaries | `SentenceWindowNodeParser` | Window=3 sentences | Narrative context |
| Clinical notes | `SentenceWindowNodeParser` | Window=3 sentences | Narrative context |
| Insurance/EOB | `SentenceSplitter` | 512 tokens, 50 overlap | Keep service line + amounts together |

---

## iOS App Structure

```
HealthRecordsAI/
├── App/                    # @main entry, ModelContainer, DI
├── Features/
│   ├── Onboarding/
│   ├── DocumentImport/     # VisionKit scanner + file picker
│   ├── DocumentLibrary/    # List view, filter by type
│   ├── Chat/               # SSE streaming chat
│   ├── Timeline/           # Chronological health events
│   └── DocumentDetail/     # Explainer + original doc
├── Services/               # All actors — APIClient, AuthService, DocumentProcessor
├── Persistence/            # SwiftData stack + models + repository
└── Core/                   # AuthManager, Keychain, AppLock, extensions
```

**Architecture:** MVVM + `@Observable` + `@MainActor` ViewModels. `actor` for service layer (thread-safe). DI via `EnvironmentValues`.

---

## Backend Structure

```
backend/app/
├── api/          # auth.py, documents.py, chat.py (SSE)
├── services/     # document_service, extraction_service, chat_service, timeline_service
├── ai/           # pipeline.py, query_engine.py, chunking.py, prompts.py
├── models/       # database.py (SQLAlchemy), schemas.py (Pydantic)
├── core/         # auth.py (JWT), security.py (bcrypt), storage.py (Supabase)
└── background/   # tasks.py (FastAPI BackgroundTasks → Celery later)
```

---

## Security Layers

1. **iOS App Transport Security** — HTTPS enforced, TLS 1.3
2. **JWT** — 15 min access token, 30 day refresh (rotated on use), Keychain only
3. **iOS Data Protection** — `NSFileProtectionComplete` on SwiftData + files
4. **Biometric Lock** — Face ID / Touch ID via `LocalAuthentication`
5. **Backend** — JWT validation on every request, Supabase RLS, Qdrant always filtered by `user_id`, signed URLs for storage (1-hour expiry)
6. **Privacy** — On-device OCR before upload, explicit user consent before first AI analysis, full data delete cascade

---

## Supabase Schema Overview

Tables: `documents`, `analysis_results`, `health_events`, `chat_messages`

- All tables have RLS enabled with `auth.uid() = user_id` policies
- `documents.status`: `processing | complete | failed`
- `analysis_results.lab_values`, `medications`, `diagnoses`, `key_findings` stored as JSONB
- `health_events.category`: `diagnosis | medication | lab | procedure | visit | imaging | insurance`

---

## Free-Tier Dev Setup

```bash
# Required env vars (copy from free-stack.md for details)
GOOGLE_API_KEY=       # aistudio.google.com/apikey
SUPABASE_URL=
SUPABASE_SERVICE_KEY=
QDRANT_URL=           # optional in dev — uses local Chroma without this
JWT_SECRET_KEY=       # openssl rand -hex 32
ENV=development       # switches vector DB: development→Chroma, production→Qdrant

# Run
docker run -p 6333:6333 qdrant/qdrant   # only if testing Qdrant locally
uvicorn app.main:app --reload --port 8000
```

Qdrant Cloud free tier suspends after 1 week inactivity — ping `client.get_collections()` on startup to keep alive.
Supabase free tier pauses after 1 week inactivity — any DB query resets the timer.

---

## Sprint Plan (8 Weeks)

| Sprint | Weeks | Focus |
|--------|-------|-------|
| 1 | 1–2 | Auth, Supabase schema + RLS, iOS project + upload |
| 2 | 3–4 | Document pipeline: extract → embed → Qdrant |
| 3 | 5–6 | RAG chat + document explainer + SSE streaming |
| 4 | 7–8 | Timeline, Face ID, onboarding, TestFlight |

---

## HIPAA Upgrade Path (Post-MVP)

- **Standard API keys:** NOT HIPAA compliant
- **Path:** Vertex AI (Gemini + Claude via third-party model) — single GCP BAA covers both
- **Supabase:** Team plan + HIPAA add-on (~$599/mo)
- v1 avoids this: user provides their own data, no provider integrations

---

## Todo / Task Tracking

Task file lives at: `/Users/architjaiswal/main/PROJECTS/medical ai app/todo.md`

Whenever completing a task or updating `todo.md`, invoke the `/task-tracking` skill.

---

## iOS Processing: On-Device vs Server-Side

**Do NOT run AI inference on-device.** All LLM and embedding work is server-side only.

| What | Where | Why |
|------|-------|-----|
| Vision OCR (`VNRecognizeTextRequest`) | On-device | Privacy — text extracted before upload |
| PDF thumbnail generation | On-device | Avoids uploading just for a preview |
| LlamaIndex chunking + embedding | Server (FastAPI) | Compute cost, model size |
| Gemini structured extraction | Server (FastAPI) | LLM call — server only |
| Qdrant indexing + RAG retrieval | Server (FastAPI) | Vector DB is remote |
| All LLM chat responses | Server (FastAPI) | Gemini/Claude are API calls |

The iOS app sends the processed PDF + extracted OCR text to the backend. It never runs an LLM or embedding model locally.

---

## SwiftUI & UX Patterns

### State Management
- **Use `@Observable` + `@MainActor`** — not `ObservableObject`/`@Published`. Requires iOS 17+.
- Instantiate `@Observable` ViewModels with `@State` in the owning view (NOT `@StateObject`).

### Navigation
- `NavigationStack` with typed enum routing via `AppCoordinator` (`@Observable`, injected via `@Environment`)
- One `NavigationStack` per tab — each tab keeps independent history
- Never mutate the nav path during a view update — only from user actions/tasks

### List vs LazyVStack
- **`List`** for the document library — better memory + scroll performance (view reuse)
- **`LazyVStack`** for the health timeline — needed for `scrollTransition` scroll effects

### Sheets & Modals
- Scanner flow → `fullScreenCover` with `.interactiveDismissDisabled()` (prevent accidental dismiss mid-scan)
- Document preview → `.sheet` with `.presentationDetents([.medium, .large])`

### Streaming Chat
- Append placeholder assistant message, update `.content` as chunks arrive from SSE
- Use `PhaseAnimator` for blinking cursor while streaming
- Always show "Not medical advice. Consult your doctor." on completed assistant messages

### Libraries (Native Only — No Third-Party UI)
| Library | Use |
|---------|-----|
| Swift Charts | Lab value charts, document type breakdown, vitals over time |
| QuickLook | Document thumbnail + PDF preview |
| TipKit (iOS 17+) | Onboarding tips (configure before first view renders) |
| StoreKit 2 | Subscriptions / IAP |
| ViewInspector | SwiftUI unit testing |

Do not add third-party chart libs, navigation frameworks, or generic UI component packs.

### Accessibility Rules
- Always combine metric + unit for VoiceOver (e.g. "Heart rate: 72 beats per minute")
- Abnormal lab values need explicit VoiceOver label ("Abnormal: above reference range")
- Use system font styles for Dynamic Type; cap custom sizes at `.accessibility2`
- WCAG AA minimum: 4.5:1 contrast for body, 3:1 for large text — use system colors (auto-compliant)

### iOS HIG Rules for Health Apps
- Never display lab values without reference ranges — a number without context is misleading
- Always disclaim AI-generated explanations: "For informational purposes only"
- Do not replicate Apple Health's UI — App Review will reject it
- Show consent screen before the first AI analysis
- Delete requires confirmation alert — never silent swipe-to-delete for health records
- No paywalls gating health features without scrutiny — Apple reviews these closely

---

## v1 Non-Goals

No diagnosis, no treatment recommendations, no EHR integrations, no Android/web, no multi-user accounts, no real-time monitoring. v1 is iOS only, personal use, informational.

---

## SwiftUI Skill

The `/swiftui-pro` skill is installed at `.agents/skills/swiftui-pro`. Use it proactively when writing any SwiftUI code — it catches deprecated API, VoiceOver gaps, and performance issues that LLMs commonly introduce.

**When to invoke it automatically (no need to ask):**
- Writing any new SwiftUI view or component
- Reviewing navigation, animation, or state management code
- After completing any iOS feature before marking it done in `todo.md`

**How to use:**
```
/swiftui-pro                          # full review
/swiftui-pro Check for deprecated API
/swiftui-pro Focus on accessibility
/swiftui-pro Look for performance problems
```

---

## Key Documents

| File | Contents |
|------|---------|
| `product-document.md` | Full PRD: features, user stories, monetization, risks |
| `architecture.md` | Full technical architecture with code samples |
| `swift-ios-research.md` | VisionKit, PDFKit, HealthKit, SwiftUI patterns, SSE |
| `swiftui-ux.md` | SwiftUI component patterns, navigation, accessibility, HIG rules |
| `backend-ai-research.md` | Gemini vs Claude, pricing, HIPAA, LlamaIndex, chunking |
| `free-stack.md` | $0/month MVP setup guide |

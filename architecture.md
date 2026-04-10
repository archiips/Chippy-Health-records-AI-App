# Architecture Document — Personal Health Records AI

**Tags:** #architecture #swift #fastapi #llamaindex #gemini #ios
**Related:** [[wiki/healthrecords-ai-app/product-document]], [[wiki/healthrecords-ai-app/swift-ios-research]], [[wiki/healthrecords-ai-app/backend-ai-research]]
**Status:** Active
**Last Updated:** 2026-04-06

---

## 1. System Overview

```
┌─────────────────────────────────────────────────────┐
│                  iOS App (Swift)                     │
│                                                      │
│  ┌──────────┐  ┌──────────┐  ┌────────────────────┐ │
│  │ VisionKit│  │ PDFKit   │  │ HealthKit (v2)     │ │
│  │ Scanner  │  │ Viewer   │  │ FHIR + Vitals      │ │
│  └────┬─────┘  └────┬─────┘  └─────────┬──────────┘ │
│       │             │                  │             │
│  ┌────▼─────────────▼──────────────────▼──────────┐ │
│  │            Document Processor                   │ │
│  │   Vision OCR → PDF Creation → Upload Queue     │ │
│  └────────────────────┬────────────────────────────┘ │
│                       │                              │
│  ┌────────────────────▼────────────────────────────┐ │
│  │              SwiftData Cache                    │ │
│  │   (NSFileProtectionComplete encryption)        │ │
│  └────────────────────┬────────────────────────────┘ │
│                       │                              │
│  ┌────────────────────▼────────────────────────────┐ │
│  │           API Service Layer (URLSession)        │ │
│  │   Multipart Upload │ SSE Streaming │ REST       │ │
│  └────────────────────┬────────────────────────────┘ │
└───────────────────────┼─────────────────────────────┘
                        │ HTTPS / TLS 1.3
                        │ JWT Bearer Token
┌───────────────────────▼─────────────────────────────┐
│               FastAPI Backend (Python)               │
│                                                      │
│  ┌──────────┐  ┌──────────────┐  ┌───────────────┐  │
│  │  Auth    │  │  Document    │  │  Chat / Q&A   │  │
│  │  Router  │  │  Router      │  │  Router (SSE) │  │
│  └────┬─────┘  └──────┬───────┘  └───────┬───────┘  │
│       │               │                  │           │
│  ┌────▼───────────────▼──────────────────▼─────────┐ │
│  │                 Service Layer                    │ │
│  │  DocumentIngestionService  │  ChatService        │ │
│  │  ExtractionService         │  TimelineService    │ │
│  └───────────────────┬──────────────────────────────┘ │
│                      │                               │
│  ┌───────────────────▼──────────────────────────────┐ │
│  │              AI Pipeline (LlamaIndex)            │ │
│  │                                                  │ │
│  │  PDF Parser → Chunker → Embedder → Qdrant Index  │ │
│  │                                                  │ │
│  │  Query Engine → Gemini LLM → Response            │ │
│  └───────────────────────────────────────────────── ┘ │
│                                                      │
│  ┌──────────────┐  ┌──────────┐  ┌───────────────┐  │
│  │   Supabase   │  │  Qdrant  │  │ Supabase      │  │
│  │   (Postgres) │  │  Vector  │  │ Storage (PDFs)│  │
│  │   user+meta  │  │   DB     │  │               │  │
│  └──────────────┘  └──────────┘  └───────────────┘  │
└─────────────────────────────────────────────────────┘
```

---

## 2. iOS App Architecture

### Minimum Deployment Target
**iOS 17** — enables `@Observable`, `SwiftData`, `scrollPosition`. Covers ~85% of active devices as of 2026.

### Project Structure

```
HealthRecordsAI/
├── App/
│   ├── HealthRecordsAIApp.swift      # @main, ModelContainer setup, DI
│   └── ContentView.swift             # Root navigation
│
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── OnboardingViewModel.swift
│   ├── DocumentImport/
│   │   ├── ImportView.swift           # Scanner + picker entry point
│   │   ├── ImportViewModel.swift      # Processing pipeline state
│   │   ├── DocumentScanner.swift      # VisionKit UIViewControllerRepresentable
│   │   └── DocumentPicker.swift       # UIDocumentPickerViewController wrapper
│   ├── DocumentLibrary/
│   │   ├── LibraryView.swift
│   │   └── LibraryViewModel.swift
│   ├── Chat/
│   │   ├── ChatView.swift             # Streaming chat UI
│   │   └── ChatViewModel.swift        # SSE stream consumer
│   ├── Timeline/
│   │   ├── TimelineView.swift         # Chronological event list
│   │   └── TimelineViewModel.swift
│   └── DocumentDetail/
│       ├── DocumentDetailView.swift   # Explainer + original doc
│       └── DocumentDetailViewModel.swift
│
├── Services/
│   ├── APIClient.swift                # Base URLSession + auth injection
│   ├── DocumentAPIService.swift       # Upload, status poll, fetch analysis
│   ├── ChatAPIService.swift           # SSE streaming chat endpoint
│   ├── AuthService.swift              # Login, register, token refresh
│   ├── HealthKitService.swift         # HKHealthStore wrapper (v2)
│   └── DocumentProcessor.swift        # Vision OCR + PDF assembly
│
├── Persistence/
│   ├── SwiftDataStack.swift           # ModelContainer + ModelContext
│   ├── Models/
│   │   ├── HealthDocument.swift       # @Model: document metadata
│   │   ├── AnalysisResult.swift       # @Model: AI extraction results
│   │   └── HealthEvent.swift          # @Model: timeline event
│   └── DocumentRepository.swift      # CRUD abstraction over SwiftData
│
├── Core/
│   ├── Auth/
│   │   ├── AuthManager.swift          # @Observable, JWT + Keychain
│   │   └── KeychainHelper.swift
│   ├── Security/
│   │   └── AppLockView.swift          # Face ID / passcode gate
│   ├── Extensions/
│   │   ├── Data+Multipart.swift
│   │   └── UIImage+PDF.swift
│   └── Environment/
│       └── AppEnvironment.swift       # DI via EnvironmentValues
│
└── Resources/
    ├── Info.plist                     # Camera, HealthKit usage descriptions
    └── HealthRecordsAI.entitlements   # HealthKit, push notifications
```

### Key SwiftData Models

```swift
@Model
class HealthDocument {
    @Attribute(.unique) var id: UUID
    var remoteID: String?              // Backend document ID
    var filename: String
    var uploadDate: Date
    var documentType: DocumentType     // enum: .lab, .discharge, .radiology, etc.
    var processingStatus: ProcessingStatus // .pending, .processing, .complete, .failed
    var extractedTextPreview: String   // First 500 chars for local search
    var thumbnailData: Data?
    @Relationship(deleteRule: .cascade) var analysisResult: AnalysisResult?
    @Relationship(deleteRule: .cascade) var events: [HealthEvent]

    enum DocumentType: String, Codable, CaseIterable {
        case lab, discharge, radiology, prescription, insurance, clinical, other
    }
    enum ProcessingStatus: String, Codable {
        case pending, uploading, processing, complete, failed
    }
}

@Model
class AnalysisResult {
    var documentID: UUID
    var summary: String                // Plain-language summary
    var keyFindings: [String]          // Bullet list of key items
    var diagnoses: [String]
    var medications: [MedicationEntry]
    var labValues: [LabValue]
    var documentDate: Date?            // Extracted date of the original document
    var providerName: String?
    var analyzedAt: Date

    struct MedicationEntry: Codable {
        var name: String; var dosage: String?; var frequency: String?
    }
    struct LabValue: Codable {
        var name: String; var value: String; var unit: String?
        var referenceRange: String?; var isAbnormal: Bool
    }
}

@Model
class HealthEvent {
    var id: UUID
    var date: Date
    var title: String
    var category: EventCategory
    var summary: String
    var documentID: UUID?              // Link back to source document

    enum EventCategory: String, Codable {
        case diagnosis, medication, lab, procedure, visit, imaging, insurance
        var color: Color { /* mapping */ }
    }
}
```

### Document Processing Pipeline

```swift
// DocumentProcessor.swift
actor DocumentProcessor {

    // Full pipeline: images → OCR → PDF → ready for upload
    func process(images: [UIImage]) async throws -> ProcessedDocument {
        // Step 1: OCR each page concurrently
        let texts = try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (i, image) in images.enumerated() {
                group.addTask {
                    let text = try await self.performOCR(on: image)
                    return (i, text)
                }
            }
            var results = [(Int, String)]()
            for try await result in group { results.append(result) }
            return results.sorted { $0.0 < $1.0 }.map(\.1)
        }

        // Step 2: Create PDF with image pages
        let pdfData = createPDF(from: images)
        let thumbnail = images.first?.preparingThumbnail(of: CGSize(width: 200, height: 280))

        return ProcessedDocument(
            pdfData: pdfData,
            extractedText: texts.joined(separator: "\n\n--- Page Break ---\n\n"),
            thumbnailData: thumbnail?.jpegData(compressionQuality: 0.7),
            pageCount: images.count
        )
    }

    private func performOCR(on image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { return "" }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        return request.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n") ?? ""
    }
}
```

### SSE Streaming (Chat)

```swift
// ChatAPIService.swift
actor ChatAPIService {
    private let apiClient: APIClient

    func streamChat(
        query: String,
        documentIDs: [UUID]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    var request = try await apiClient.authenticatedRequest(
                        for: .chatStream
                    )
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(
                        ChatRequest(query: query, documentIDs: documentIDs.map(\.uuidString))
                    )

                    let (bytes, _) = try await URLSession.shared.bytes(for: request)
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        if payload == "[DONE]" { break }
                        if let chunk = try? JSONDecoder().decode(SSEChunk.self,
                                       from: Data(payload.utf8)),
                           let text = chunk.delta {
                            continuation.yield(text)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
```

---

## 3. Backend Architecture (FastAPI + Python)

### Project Structure

```
backend/
├── app/
│   ├── main.py                        # FastAPI app, routers, CORS, lifespan
│   ├── config.py                      # Settings (Pydantic BaseSettings, .env)
│   │
│   ├── api/
│   │   ├── auth.py                    # POST /auth/register, /login, /refresh
│   │   ├── documents.py               # POST /documents, GET /documents, GET /:id
│   │   └── chat.py                    # POST /chat/stream (SSE)
│   │
│   ├── services/
│   │   ├── document_service.py        # Orchestrates ingestion pipeline
│   │   ├── extraction_service.py      # LLM-based structured extraction
│   │   ├── chat_service.py            # RAG query + streaming
│   │   └── timeline_service.py        # Aggregate events across documents
│   │
│   ├── ai/
│   │   ├── pipeline.py                # LlamaIndex ingestion pipeline
│   │   ├── query_engine.py            # RAG query engine setup
│   │   ├── chunking.py                # Medical-aware chunking strategies
│   │   └── prompts.py                 # All LLM prompt templates
│   │
│   ├── models/
│   │   ├── database.py                # SQLAlchemy models
│   │   └── schemas.py                 # Pydantic request/response schemas
│   │
│   ├── core/
│   │   ├── auth.py                    # JWT creation, validation, deps
│   │   ├── security.py                # Password hashing (bcrypt)
│   │   └── storage.py                 # Supabase Storage client
│   │
│   └── background/
│       └── tasks.py                   # FastAPI BackgroundTasks for async ingestion
│
├── requirements.txt
├── Dockerfile
└── .env.example
```

### Core Dependencies

```
fastapi==0.115+
uvicorn[standard]
python-multipart              # file upload
python-jose[cryptography]     # JWT
passlib[bcrypt]               # password hashing
sqlalchemy[asyncio]           # async ORM
asyncpg                       # async Postgres driver
supabase                      # Supabase client (storage + auth)
llama-index-core
llama-index-llms-google-genai # Gemini integration
llama-index-embeddings-google # Google embeddings
llama-index-vector-stores-qdrant
qdrant-client
pymupdf                       # PDF text extraction (fitz)
pillow                        # image handling
python-dotenv
```

### Document Ingestion Endpoint

```python
# api/documents.py
@router.post("/documents", response_model=DocumentResponse)
async def upload_document(
    file: UploadFile = File(...),
    background_tasks: BackgroundTasks = BackgroundTasks(),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    # 1. Validate file type
    if file.content_type not in ["application/pdf", "image/jpeg", "image/png"]:
        raise HTTPException(400, "Unsupported file type")

    # 2. Store PDF in Supabase Storage
    contents = await file.read()
    storage_path = f"{current_user.id}/{uuid4()}/{file.filename}"
    storage_client.storage.from_("documents").upload(storage_path, contents)

    # 3. Create DB record
    doc = Document(
        user_id=current_user.id,
        filename=file.filename,
        storage_path=storage_path,
        status="processing"
    )
    db.add(doc)
    await db.commit()

    # 4. Queue background ingestion
    background_tasks.add_task(ingest_document, doc.id, contents, current_user.id)

    return DocumentResponse(id=doc.id, status="processing")
```

### AI Ingestion Pipeline (LlamaIndex + Gemini)

```python
# ai/pipeline.py
from llama_index.core import VectorStoreIndex, Document
from llama_index.core.node_parser import SentenceSplitter
from llama_index.llms.google_genai import GoogleGenAI
from llama_index.embeddings.google_genai import GoogleGenAIEmbedding
from llama_index.vector_stores.qdrant import QdrantVectorStore
import qdrant_client
import fitz  # PyMuPDF

class MedicalDocumentPipeline:

    def __init__(self, user_id: str):
        self.user_id = user_id
        self.llm = GoogleGenAI(
            model="gemini-2.5-pro",           # See AI model selection section
            api_key=settings.GEMINI_API_KEY
        )
        self.embed_model = GoogleGenAIEmbedding(
            model_name="text-embedding-004",
            api_key=settings.GEMINI_API_KEY
        )
        self.qdrant = qdrant_client.QdrantClient(url=settings.QDRANT_URL)
        self.vector_store = QdrantVectorStore(
            client=self.qdrant,
            collection_name=f"user_{user_id}"  # Per-user isolation
        )

    async def ingest(self, pdf_bytes: bytes, doc_id: str) -> ExtractionResult:
        # Step 1: Extract text with PyMuPDF (handles text-based PDFs well)
        text = self._extract_text(pdf_bytes)

        # Step 2: Medical-aware chunking
        nodes = self._chunk_medical_document(text, doc_id)

        # Step 3: Embed + store in Qdrant
        index = VectorStoreIndex(
            nodes,
            vector_store=self.vector_store,
            embed_model=self.embed_model,
            show_progress=False
        )

        # Step 4: Structured extraction (separate LLM call)
        extraction = await self._extract_structured_data(text)

        return extraction

    def _extract_text(self, pdf_bytes: bytes) -> str:
        doc = fitz.open(stream=pdf_bytes, filetype="pdf")
        text = ""
        for page in doc:
            text += page.get_text("text")
            # get_text("dict") for layout-aware extraction if needed
        return text

    def _chunk_medical_document(self, text: str, doc_id: str) -> list:
        # Medical documents need context-aware chunking:
        # - Lab results: keep each panel together (don't split CBC across chunks)
        # - Narrative notes: sentence-window chunking
        # - Radiology reports: keep impression separate from findings

        splitter = SentenceSplitter(
            chunk_size=512,
            chunk_overlap=64,             # Overlap preserves context at boundaries
            paragraph_separator="\n\n",
        )
        nodes = splitter.get_nodes_from_documents([Document(text=text)])
        for node in nodes:
            node.metadata["document_id"] = doc_id
            node.metadata["user_id"] = self.user_id
        return nodes

    async def _extract_structured_data(self, text: str) -> ExtractionResult:
        prompt = EXTRACTION_PROMPT.format(document_text=text[:8000])  # First 8K chars
        response = await self.llm.acomplete(prompt)
        return parse_extraction_response(response.text)
```

### LLM Prompt Templates

```python
# ai/prompts.py

EXTRACTION_PROMPT = """You are a medical document analyst. Extract structured information from the following medical document.

Return a JSON object with these fields:
- document_type: one of [lab_result, discharge_summary, radiology_report, prescription, clinic_note, insurance_eob, other]
- document_date: ISO date string if found, null otherwise
- provider_name: name of doctor/facility if found
- diagnoses: list of diagnoses/conditions mentioned (use plain English, not ICD codes)
- medications: list of {name, dosage, frequency} objects
- lab_values: list of {name, value, unit, reference_range, is_abnormal} objects
- key_findings: list of 3-5 most important findings in plain English
- summary: 2-3 sentence plain-language summary a patient would understand
- patient_age: if mentioned

Document:
{document_text}

Return valid JSON only."""


CHAT_SYSTEM_PROMPT = """You are a personal health records assistant helping a patient understand their own medical history.

You have access to the patient's medical documents via the provided context. Your role is to:
1. Answer questions about their health records clearly and in plain language
2. Always cite which document your answer comes from
3. Explain medical terminology when relevant
4. Be empathetic and clear
5. ALWAYS include "This is not medical advice. Please consult your doctor." for any health-related questions

You must ONLY answer based on the provided document context. If the answer is not in the documents, say so clearly. Do not make up medical information.

Available documents context:
{context}"""


EXPLAINER_PROMPT = """Explain the following medical document to a patient in plain, friendly language.

Requirements:
- Write as if talking to a non-medical person
- Define any medical terms you use
- Highlight the 3 most important things they should know
- End with: "This explanation is for informational purposes only. Ask your doctor if you have questions."
- Keep the explanation under 300 words

Document:
{document_text}"""
```

### RAG Chat with Streaming

```python
# api/chat.py
from fastapi.responses import StreamingResponse

@router.post("/chat/stream")
async def chat_stream(
    request: ChatRequest,
    current_user: User = Depends(get_current_user)
):
    async def generate():
        query_engine = await get_user_query_engine(current_user.id)

        # Retrieve relevant chunks from user's documents
        retrieval = await query_engine.aretrieve(request.query)
        context = "\n\n".join([n.text for n in retrieval])

        # Build messages
        system = CHAT_SYSTEM_PROMPT.format(context=context)
        messages = [{"role": "user", "parts": [request.query]}]

        # Stream from Gemini 2.5 Flash (free tier or paid — same code)
        import google.generativeai as genai
        model = genai.GenerativeModel(
            "gemini-2.5-flash",   # ⚠️ 2.0 Flash deprecated June 2026 — use 2.5
            system_instruction=system
        )
        async for chunk in await model.generate_content_async(
            messages, stream=True,
            generation_config={"max_output_tokens": 1024}
        ):
            if chunk.text:
                yield f"data: {json.dumps({'delta': chunk.text})}\n\n"
        yield "data: [DONE]\n\n"

    return StreamingResponse(generate(), media_type="text/event-stream")
```

---

## 4. AI Model Selection

### Free-Tier Path (MVP / $0/month)

**Use Gemini 2.5 Flash for everything on the free tier — one API key covers LLM + embeddings.**

Get a free key at [aistudio.google.com/apikey](https://aistudio.google.com/apikey).

| Task | Free Model | Paid Upgrade |
|------|-----------|--------------|
| Document extraction | Gemini 2.5 Flash (free, 250 RPD) | Gemini 2.5 Flash (billing enabled) |
| Patient chat Q&A | Gemini 2.5 Flash (free, 250 RPD) | Claude Sonnet 4.6 (better for medical Q&A) |
| Radiology / multimodal | Gemini 2.5 Flash (free) | Gemini 2.5 Pro (Med-Gemini advantage) |
| Background classification | Gemini 2.5 Flash-Lite (free, 1,500 RPD) | Same |
| Embeddings | `text-embedding-004` (free, 1,500 req/day) | Same model, paid tier |
| Embeddings (alt, no limits) | BGE-large-en-v1.5 (self-hosted, free) | — |
| Chat fallback | OpenRouter free (Llama 3.3 70B, 200 req/day) | OpenRouter paid |

**Free tier limits:** Gemini 2.5 Flash = 10 RPM / 250 RPD. Fine for solo dev and early beta (< ~50 users with light usage).

See [[wiki/healthrecords-ai-app/free-stack]] for full free-tier setup, Chroma/Qdrant switching, and data privacy warnings.
See [[wiki/healthrecords-ai-app/backend-ai-research]] for paid model comparison, HIPAA compliance path, and Claude vs Gemini analysis.

### Context Window Strategy
- Gemini 2.5 Pro: **1M token context** — can process an entire patient record set in one call for complex questions
- Use RAG (Qdrant retrieval) for routine chat Q&A (cheaper, faster)
- Use full-context call for appointment prep summary (inject all relevant documents directly)

### Qdrant Collection Design

**Use a single collection with payload-based tenant isolation — NOT one collection per user.**
Per-user collections break down at hundreds of users.

```
Single collection: "medical_records"
  - user_id payload field indexed with is_tenant=True (Qdrant v1.16+ tiered multitenancy)
  - Payload: document_id, user_id, document_type, document_date, chunk_index
  - Vector: 768-dim (text-embedding-004)
  - Hybrid search: BM25 + dense (enable_hybrid=True)
  - All queries ALWAYS filtered by user_id — enforced at Qdrant level

Index config:
  - HNSW: ef_construct=128, m=16
  - Scalar quantization (4x memory reduction, minimal accuracy loss)
  - Payload index on user_id (keyword, is_tenant=True) + doc_type (keyword)
```

**Background Jobs:** Use Celery + Redis for ingestion in production. FastAPI BackgroundTasks is fine for MVP but document ingestion (30–120 sec) will degrade API latency for all users if run in the web process.

---

## 5. Data Architecture

### Supabase Schema (Postgres)

```sql
-- Users (handled by Supabase Auth)
-- auth.users table is auto-managed

-- Documents
CREATE TABLE documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    filename TEXT NOT NULL,
    storage_path TEXT NOT NULL,           -- Supabase Storage path
    document_type TEXT,                   -- lab, discharge, radiology, etc.
    document_date DATE,                   -- extracted date of original doc
    status TEXT NOT NULL DEFAULT 'processing',  -- processing | complete | failed
    page_count INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    processed_at TIMESTAMPTZ,
    INDEX idx_documents_user_id (user_id),
    INDEX idx_documents_status (status)
);

-- Analysis results
CREATE TABLE analysis_results (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID REFERENCES documents(id) ON DELETE CASCADE UNIQUE,
    summary TEXT,
    key_findings JSONB,                   -- array of strings
    diagnoses JSONB,                      -- array of strings
    medications JSONB,                    -- array of {name, dosage, frequency}
    lab_values JSONB,                     -- array of {name, value, unit, is_abnormal}
    provider_name TEXT,
    raw_extraction JSONB,                 -- full LLM output for debugging
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Health events (timeline)
CREATE TABLE health_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    document_id UUID REFERENCES documents(id),
    event_date DATE NOT NULL,
    title TEXT NOT NULL,
    category TEXT NOT NULL,               -- diagnosis | medication | lab | procedure | visit
    summary TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    INDEX idx_events_user_date (user_id, event_date DESC)
);

-- Chat history (optional — for conversation context)
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL,                   -- user | assistant
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    INDEX idx_chat_user (user_id, created_at DESC)
);

-- Row Level Security (critical for multi-user)
ALTER TABLE documents ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_own_documents" ON documents
    USING (auth.uid() = user_id);

ALTER TABLE analysis_results ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_own_analysis" ON analysis_results
    USING (document_id IN (SELECT id FROM documents WHERE user_id = auth.uid()));
```

### File Storage (Supabase Storage)

```
Bucket: "documents" (private, not public)
Path structure: {user_id}/{document_id}/{filename}.pdf

Access: signed URLs only (expires in 1 hour)
Max file size: 25MB per document
```

---

## 6. Security Architecture

### Defense in Depth

```
Layer 1: App Transport Security (iOS)
  - HTTPS enforced by iOS ATS
  - TLS 1.3 minimum
  - Certificate pinning (v2, after API is stable)

Layer 2: Authentication
  - JWT access tokens (15 min expiry)
  - Refresh tokens (30 day expiry, rotated on use)
  - Tokens stored in iOS Keychain (kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
  - Biometric app lock (Face ID / Touch ID)

Layer 3: iOS Data Protection
  - SwiftData store: NSFileProtectionComplete
  - PDF files: FileProtectionType.complete
  - No iCloud sync (cloudKitDatabase: .none)

Layer 4: Backend Authorization
  - JWT validation on every request
  - Supabase RLS: users can only access their own rows
  - Qdrant queries always filtered by user_id
  - Supabase Storage: signed URLs only

Layer 5: Data Minimization
  - On-device OCR before upload (text extracted locally first)
  - Thumbnails generated on-device
  - Only processed PDF and extracted text sent to backend
  - No analytics SDKs with health data access
```

### Privacy-First Design Principles
1. On-device OCR runs before anything leaves the device
2. User explicitly consents to AI analysis before first document is processed
3. User can delete all their data (cascade deletes in DB, storage cleanup, Qdrant collection purge)
4. No third-party analytics on health features

---

## 7. API Contract

### Auth

```
POST /auth/register
  Body: { email, password }
  Returns: { access_token, refresh_token, user_id }

POST /auth/login
  Body: { email, password }
  Returns: { access_token, refresh_token, user_id }

POST /auth/refresh
  Body: { refresh_token }
  Returns: { access_token, refresh_token }
```

### Documents

```
POST /documents
  Auth: Bearer token
  Body: multipart/form-data { file: PDF }
  Returns: { id, status: "processing" }

GET /documents
  Auth: Bearer token
  Returns: [{ id, filename, document_type, status, document_date, created_at }]

GET /documents/{id}
  Auth: Bearer token
  Returns: { document, analysis_result, events }

DELETE /documents/{id}
  Auth: Bearer token
  Returns: 204 No Content

GET /documents/{id}/signed-url
  Auth: Bearer token
  Returns: { url, expires_at }           (for viewing original PDF in app)
```

### Chat

```
POST /chat/stream
  Auth: Bearer token
  Body: { query: string, document_ids?: string[] }
  Returns: text/event-stream
    data: {"delta": "chunk of text"}
    data: [DONE]
```

### Timeline

```
GET /timeline
  Auth: Bearer token
  Query: ?from=2024-01-01&to=2026-04-06&category=lab
  Returns: [{ id, event_date, title, category, summary, document_id }]
```

---

## 8. Infrastructure

### Local Development

```bash
# Backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
docker run -p 6333:6333 qdrant/qdrant   # Qdrant local
uvicorn app.main:app --reload --port 8000

# iOS
# Open HealthRecordsAI.xcodeproj in Xcode
# Set BASE_URL = "http://localhost:8000" in scheme environment
# Run on physical device (VisionKit requires device)
```

### Production Deployment

```
iOS: App Store (TestFlight for beta)

Backend:
  FastAPI → Railway or Fly.io (auto-deploy from GitHub)
  Supabase → Supabase Cloud (managed Postgres + Storage + Auth)
  Qdrant → Qdrant Cloud (free tier: 1GB, enough for early users)

Environment variables:
  GEMINI_API_KEY
  SUPABASE_URL
  SUPABASE_SERVICE_KEY
  QDRANT_URL
  QDRANT_API_KEY
  JWT_SECRET_KEY
  JWT_ALGORITHM=HS256
```

### Monthly Cost Estimate

#### Dev / Solo Testing: $0/month (Free Stack)

| Service | Cost |
|---------|------|
| Gemini API (AI Studio free tier) | $0 |
| Supabase free tier | $0 |
| Qdrant Cloud free tier OR local Chroma | $0 |
| OpenRouter free models (fallback) | $0 |
| **Total** | **$0** |

See [[wiki/healthrecords-ai-app/free-stack]] for full free-tier setup guide.

#### Early Beta (~100 users): ~$10–30/month

| Service | Cost |
|---------|------|
| Gemini API (billing enabled, usage-based) | ~$5–15/mo |
| Supabase free tier | $0 |
| Qdrant Cloud free tier | $0 |
| Railway Starter | $5/mo |
| **Total** | **~$10–20/mo** |

#### Growth (~500 users): ~$80–130/month

| Service | Cost |
|---------|------|
| Gemini 2.5 Flash (extraction) | ~$8/mo (10K docs) |
| Claude Sonnet 4.6 (chat, cached) | ~$75/mo (100K queries) |
| Supabase Pro | $25/mo |
| Qdrant Cloud | $0 (free tier, < 1M vectors) |
| Railway | ~$20/mo |
| **Total** | **~$128/mo** |

**HIPAA upgrade path:** Supabase Team + HIPAA add-on (~$599/mo) + Vertex AI BAA (free) + Anthropic Enterprise BAA (sales). Only needed when storing real patient data from providers.

---

## 9. Development Milestones

### Sprint 1 (Weeks 1–2): Foundation
- [ ] FastAPI project setup + auth (register/login/refresh/JWT)
- [ ] Supabase schema + RLS policies
- [ ] iOS project setup (SwiftData models, APIClient, AuthManager)
- [ ] Basic document upload (iOS multipart → FastAPI → Supabase Storage)

### Sprint 2 (Weeks 3–4): Document Pipeline
- [ ] PyMuPDF text extraction on backend
- [ ] LlamaIndex ingestion pipeline (chunk → embed → Qdrant)
- [ ] Gemini structured extraction prompt + parsing
- [ ] iOS processing pipeline (VisionKit scanner → OCR → upload)
- [ ] Document library view (list + thumbnail + status)

### Sprint 3 (Weeks 5–6): AI Features
- [ ] RAG query engine (Qdrant retrieval → Gemini response)
- [ ] SSE streaming chat endpoint
- [ ] iOS chat view with streaming
- [ ] Document explainer (per-document plain-language summary)

### Sprint 4 (Weeks 7–8): Polish + Launch
- [ ] Health timeline view
- [ ] Face ID app lock
- [ ] Onboarding flow + consent screen
- [ ] Error handling + empty states
- [ ] TestFlight beta

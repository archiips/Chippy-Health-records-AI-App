# Backend & AI Research Notes

**Tags:** #gemini #claude #llamaindex #fastapi #qdrant #medical-rag
**Related:** [[wiki/healthrecords-ai-app/architecture]], [[wiki/healthrecords-ai-app/product-document]]
**Source:** Deep research — April 2026

---

## CRITICAL: Gemini 2.0 Flash is Deprecated

**Gemini 2.0 Flash is deprecated as of June 1, 2026. Do NOT build on it.**

Use:
- **Gemini 2.5 Flash** — fast/cheap extraction and classification
- **Gemini 2.5 Pro** — complex reasoning, radiology, full-context queries
- **Gemini 2.5 Flash-Lite** — cheapest option for high-volume batch tasks

---

## Gemini vs Claude — Final Recommendation

**Use a hybrid architecture — neither alone is optimal.**

| Task | Model | Reason |
|------|-------|--------|
| Batch PDF ingestion / structured extraction | Gemini 2.5 Flash | Cheapest, native PDF support, fast |
| Radiology report / image interpretation | Gemini 2.5 Pro | Med-Gemini research advantage, strong multimodal |
| Patient Q&A (streaming chat) | Claude Sonnet 4.6 | Fewer hallucinations, safer conservative tone |
| Medical term explanation | Claude Sonnet 4.6 | Better nuance, explicit about uncertainty |
| Pattern identification across records | Claude Sonnet 4.6 | Better cross-document reasoning |
| Background classification/tagging | Gemini 2.5 Flash-Lite | Cost-optimized |

---

## Context Window

| Model | Window | Long-context pricing |
|-------|--------|---------------------|
| Gemini 2.5 Pro | 1M tokens | **2x price above 200K** |
| Gemini 2.5 Flash | 1M tokens | Same 1M, no surcharge |
| Claude Sonnet 4.6 | 1M tokens | **Flat pricing — no surcharge at any length** |

**Key:** Claude has no price cliff at 200K tokens. For a user with 50+ documents (potentially 300K–500K tokens), Claude's flat pricing is a meaningful advantage for full-context queries. Use RAG for routine chat anyway; reserve full-context for "appointment prep" summaries.

---

## Gemini's Medical AI Advantage

### Med-Gemini (research, not yet API)
- Fine-tuned on de-identified medical datasets
- **91.1% accuracy on MedQA** benchmark (+4.6pp over prior best)
- Radiology boards: Gemini 2.5 Pro scored 76.0% vs 72.9% average human examinee
- 57% of AI-generated radiology reports rated "equivalent or better" than radiologist originals

### MedGemma (open-source, available now via HuggingFace)
- Released May 2025, updated to v1.5
- 4B and 27B parameter sizes, both multimodal
- MedGemma 27B: **87.7% on MedQA** (~1/10th inference cost of DeepSeek R1)
- Fully open-source (weights + training scripts)
- Can be fine-tuned with LoRA on your own patient record data
- **Option:** Self-host MedGemma 27B for extraction pipeline, use Gemini/Claude for patient-facing Q&A

---

## Gemini Native PDF Handling

```python
import google.generativeai as genai

# Upload PDF directly — no parsing needed
file = genai.upload_file("lab_result.pdf", mime_type="application/pdf")
# NOTE: Files expire after 48 hours — you must store PDFs yourself in Supabase Storage

model = genai.GenerativeModel("gemini-2.5-flash")
response = model.generate_content([
    file,
    "Extract: diagnoses, medications, lab values as JSON"
])
```

- Accepts PDFs up to **50MB and 1,000 pages** per file
- Processes embedded text, OCRs scanned pages, and interprets charts/tables in one pass
- Native PDF text is **not charged as tokens** — major cost saving for text-heavy PDFs
- 48-hour TTL on uploaded files — always store originals in Supabase Storage

---

## Pricing (April 2026)

### Gemini API

| Model | Input (per 1M tokens) | Output (per 1M tokens) |
|-------|----------------------|----------------------|
| Gemini 2.5 Flash | ~$0.15–$0.30 | ~$0.60–$3.50 |
| Gemini 2.5 Pro (≤200K) | $1.25 | $10.00 |
| Gemini 2.5 Pro (>200K) | **$2.50** | **$15.00** |
| Gemini 2.5 Pro (batch) | $0.625 | $5.00 |
| Gemini 2.5 Flash-Lite | $0.10 | $0.40 |

### Claude API

| Model | Input (per 1M tokens) | Output (per 1M tokens) | Cache hit |
|-------|----------------------|----------------------|-----------|
| Claude Haiku 4.5 | $1.00 | $5.00 | $0.10 |
| Claude Sonnet 4.6 | $3.00 | $15.00 | $0.30 |
| Claude Sonnet 4.6 (batch) | $1.50 | $7.50 | — |

### Cost at Scale (10K document ingestions/month + 100K chat queries/month)

| Task | Best model | Monthly cost |
|------|-----------|-------------|
| Document ingestion (5K tokens each) | Gemini 2.5 Flash | ~$8 |
| Chat Q&A (2K in + 500 out) | Claude Sonnet 4.6 | ~$750 |
| Chat Q&A (same, cached) | Claude Sonnet 4.6 | ~$75 (90% savings) |

**→ Use prompt caching for repeated system prompts and document context. 90% cost reduction.**

---

## HIPAA Compliance Path

### Gemini / Google
- **AI Studio (consumer tier): NOT HIPAA-compliant**
- **Vertex AI: HIPAA-eligible** with signed Google BAA
- Requirement: BAA + `regulated-data` flag enabled at GCP project level
- Certifications: ISO 42001, HITRUST (May 2025), PCI-DSS v4.0

### Claude / Anthropic
- Standard API: **NOT HIPAA-compliant** (no BAA)
- **Anthropic Enterprise: HIPAA-ready** (sales-assisted, not self-serve)
- Claude on AWS Bedrock: HIPAA-eligible (AWS BAA covers it)
- Claude on Vertex AI: HIPAA-eligible (Google BAA covers it)
- Anthropic has BAAs with AWS, Google, and Microsoft — only major AI provider with all three

### Simplest Production Path
→ **Vertex AI for both Gemini and Claude** (single vendor, single BAA, same GCP infrastructure)
→ Claude is available on Vertex AI as a third-party model

---

## LlamaIndex + Gemini Integration (Current v0.4.2+)

```python
# Use GoogleGenAIEmbedding — NOT the deprecated GeminiEmbedding
pip install llama-index-embeddings-google-genai llama-index-llms-gemini

from llama_index.embeddings.google_genai import GoogleGenAIEmbedding
from llama_index.llms.gemini import Gemini
from llama_index.core import Settings

Settings.embed_model = GoogleGenAIEmbedding(
    model_name="models/text-embedding-004"
)
Settings.llm = Gemini(model="models/gemini-2.5-flash")

# For Vertex AI (production/HIPAA):
from llama_index.llms.vertex import Vertex
from llama_index.embeddings.vertex import VertexTextEmbedding

Settings.llm = Vertex(model="gemini-2.5-pro", project="your-gcp-project", location="us-central1")
Settings.embed_model = VertexTextEmbedding(model_name="text-embedding-004", project="your-gcp-project")
```

---

## Embedding Models

Research finding: **General-domain models outperform specialized medical models on EHR retrieval tasks.** PubMed-trained models don't transfer well to clinical documents (discharge summaries, lab results).

| Model | Dimensions | Notes |
|-------|-----------|-------|
| `text-embedding-004` (Google) | 768 | **Best choice for Gemini stack** |
| `gemini-embedding-exp-03-07` | 3072 | State-of-the-art, experimental pricing |
| `BGE-large-en-v1.5` | 1024 | **Best open-source option**, strong on EHRs |
| `MedCPT` | 768 | Good for PubMed retrieval, weaker on EHRs |

→ Use `text-embedding-004`. Do not pay premium for medically fine-tuned embeddings.

---

## Chunking Strategy by Document Type

**Critical:** Document-type-aware chunking achieves 87% retrieval accuracy vs 50% for fixed chunking in clinical settings (PMC 2025).

| Document Type | Strategy | Chunk Size | Why |
|--------------|---------|-----------|-----|
| Lab results | `SentenceSplitter` | 256 tokens, 20 overlap | Keep analyte + value + reference range together |
| Radiology reports | `SemanticSplitterNodeParser` | Adaptive | Preserves FINDINGS/IMPRESSION sections |
| Discharge summaries | `SentenceWindowNodeParser` | Window=3 sentences | Context around key findings |
| Clinical notes | `SentenceWindowNodeParser` | Window=3 sentences | Narrative context needed |
| EOBs / Insurance | `SentenceSplitter` | 512 tokens, 50 overlap | Keep service line + amounts together |

---

## Qdrant — Multi-User Isolation

**Use a single collection with payload-based tenant isolation** — NOT one collection per user. Per-user collections break down at hundreds of users.

```python
# Single collection, user_id as indexed tenant field
client.create_collection(
    collection_name="medical_records",
    vectors_config=VectorParams(size=768, distance=Distance.COSINE)
)
client.create_payload_index(
    collection_name="medical_records",
    field_name="user_id",
    field_schema=PayloadSchemaType.KEYWORD,
    is_tenant=True  # Qdrant v1.16+ tiered multitenancy
)

# Query always filtered by user_id — users never see each other's data
vector_store = QdrantVectorStore(
    client=client,
    collection_name="medical_records",
    filters={"user_id": user_id},
    enable_hybrid=True  # BM25 + dense
)
```

---

## Background Jobs: Celery + Redis (Not FastAPI BackgroundTasks)

Document ingestion takes 30–120 seconds per document. Running in FastAPI BackgroundTasks degrades API latency for all users on the same process.

| Factor | FastAPI BackgroundTasks | Celery + Redis |
|--------|------------------------|----------------|
| Runs in web process | Yes (blocks) | No (separate workers) |
| Task persistence on crash | No | Yes |
| Retries / backoff | Manual | Built-in |
| Monitoring | No | Celery Flower dashboard |

Use `BackgroundTasks` for MVP, migrate to Celery before you have real users.

---

## Supabase Storage vs S3

**Use Supabase Storage.** It integrates with the same RLS policies as your Postgres tables — a user can only access their own files at the storage layer, enforced by the same JWT.

```sql
-- Storage RLS policy — users can only access their own folder
CREATE POLICY "users_own_documents"
ON storage.objects FOR ALL
USING (
    bucket_id = 'medical-docs'
    AND (storage.foldername(name))[1] = 'users'
    AND (storage.foldername(name))[2] = auth.uid()::text
);
```

HIPAA path: Supabase Team plan + HIPAA add-on includes BAA. S3-compatible API means you can switch later without changing code.

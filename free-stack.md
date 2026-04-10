# Free-Tier Stack Guide — Chippy

**Tags:** #free-tier #gemini #openrouter #chroma #supabase #zero-cost
**Related:** [[wiki/healthrecords-ai-app/backend-ai-research]], [[wiki/healthrecords-ai-app/architecture]]
**Source:** Research — April 2026

---

## TL;DR — $0/month MVP Stack

| Layer | Free Option | Limit | Notes |
|-------|-------------|-------|-------|
| Extraction LLM | Gemini 2.5 Flash (AI Studio) | 10 RPM / 250 RPD | Primary choice |
| Chat LLM | Gemini 2.5 Flash (AI Studio) | 10 RPM / 250 RPD | Same model works |
| Chat LLM (alt) | OpenRouter free models | 200 req/day | Llama 3.3 70B, DeepSeek R1 |
| Embeddings | Gemini `text-embedding-004` | 1,500 req/day | Same API key |
| Embeddings (alt) | BGE-large-en-v1.5 (self-hosted) | Unlimited | Runs on CPU, 1GB RAM |
| Vector DB (dev) | Chroma (local) | Unlimited | No credentials needed |
| Vector DB (prod) | Qdrant Cloud free | 1M vectors / 1GB | Suspends after 1 week inactivity |
| Database | Supabase free tier | 500MB / 50K MAU | Same RLS/Auth features |
| Storage | Supabase free tier | 1GB included | |
| Backend hosting | Railway Starter | $5 credit/mo | Enough for solo dev |

---

## Gemini API Free Tier (April 2026)

**Access via:** Google AI Studio (`aistudio.google.com`) — NOT Vertex AI (Vertex requires billing).

| Model | RPM | RPD | TPM |
|-------|-----|-----|-----|
| Gemini 2.5 Flash | 10 | 250 | 250K |
| Gemini 2.5 Pro | 5 | 100 | 250K |
| Gemini 2.5 Flash-Lite | 30 | 1,500 | 1M |
| `text-embedding-004` | 1,500 | — | 1M |

**Key notes:**
- RPD (requests per day) is the binding constraint, not RPM for low-traffic MVP
- 250 RPD = ~8 ingestion + 242 chat queries daily — fine for solo testing and early beta
- Gemini 2.5 Flash handles both extraction AND chat well — no need for a second model on free tier
- Google AI Studio free tier: **data may be used to improve Google models** — do NOT use with real patient data
- For production with real user data: upgrade to paid Gemini API (billing enabled) — usage-based, no subscription

```python
# Free tier — Google AI Studio key (not Vertex)
import os
os.environ["GOOGLE_API_KEY"] = "your-ai-studio-key"  # from aistudio.google.com/apikey

from llama_index.llms.google_genai import GoogleGenAI
from llama_index.embeddings.google_genai import GoogleGenAIEmbedding

llm = GoogleGenAI(model="gemini-2.5-flash")              # extraction + chat
embed_model = GoogleGenAIEmbedding(model_name="models/text-embedding-004")
```

---

## OpenRouter Free Models (Fallback)

**Access via:** `openrouter.ai` — one API key, OpenAI-compatible interface.

| Model | Context | Notes |
|-------|---------|-------|
| `meta-llama/llama-3.3-70b-instruct:free` | 131K | Strong reasoning, good for Q&A |
| `deepseek/deepseek-r1:free` | 64K | Best free reasoning model |
| `qwen/qwen3-coder-480b-a35b-instruct:free` | 262K | Massive context window |
| `mistralai/mistral-small-3.1-24b-instruct:free` | 128K | Fast, balanced |
| `google/gemma-3-27b-it:free` | 96K | Google open weights |
| `nvidia/llama-3.3-nemotron-super-49b-v1:free` | 131K | NVIDIA fine-tuned |

**Limits:** ~20 RPM / ~200 requests/day per model (community rate limits, not SLA-guaranteed).

```python
# OpenRouter via OpenAI-compatible SDK
from openai import AsyncOpenAI

openrouter = AsyncOpenAI(
    base_url="https://openrouter.ai/api/v1",
    api_key=os.environ["OPENROUTER_API_KEY"],  # free account at openrouter.ai
)

async def chat_with_openrouter(query: str, context: str) -> str:
    response = await openrouter.chat.completions.create(
        model="meta-llama/llama-3.3-70b-instruct:free",
        messages=[
            {"role": "system", "content": CHAT_SYSTEM_PROMPT.format(context=context)},
            {"role": "user", "content": query}
        ],
        stream=True  # streaming works the same way
    )
    return response
```

**When to use OpenRouter vs Gemini:**
- Gemini free tier: primary path — same API key for LLM + embeddings
- OpenRouter: fallback if you hit Gemini RPD limits, or want to test different models
- OpenRouter has NO native PDF support — use PyMuPDF for text extraction first

---

## Embeddings: Free Options

### Option 1: Gemini `text-embedding-004` (recommended, same API key)
- 768-dim, 1,500 req/day free
- Best performance on EHR retrieval (outperforms medical-specific models)
- Drop-in with LlamaIndex

### Option 2: BGE-large-en-v1.5 (self-hosted, unlimited)

```python
pip install llama-index-embeddings-huggingface

from llama_index.embeddings.huggingface import HuggingFaceEmbedding

embed_model = HuggingFaceEmbedding(
    model_name="BAAI/bge-large-en-v1.5",
    device="cpu"  # works on CPU, ~1GB RAM, ~200ms/batch
)
```

- Completely free, no API key, no rate limits
- Runs locally — no data leaves your machine
- Slightly slower than hosted API (~200ms vs ~50ms per batch)
- **Best choice if you want 100% free with no rate limits**

---

## Vector DB: Chroma (Dev) vs Qdrant Cloud Free (Prod)

### Chroma — Fully Local (Dev)

```python
pip install llama-index-vector-stores-chroma chromadb

import chromadb
from llama_index.vector_stores.chroma import ChromaVectorStore

chroma_client = chromadb.PersistentClient(path="./chroma_db")
collection = chroma_client.get_or_create_collection("medical_records")
vector_store = ChromaVectorStore(chroma_collection=collection)
```

- Zero setup, zero cost, zero credentials
- Data persists to disk in `./chroma_db/`
- No multi-tenancy support (fine for dev with one user)
- Switch to Qdrant in production — LlamaIndex makes this a one-line change

### Qdrant Cloud Free Tier (Prod)

- 1M vectors at 768-dim / 1GB RAM / 4GB disk
- **Cluster suspends after 1 week of inactivity** — call a health check endpoint to keep alive
- Free forever if you stay under limits
- Full multi-tenancy (`is_tenant=True`) works on free tier

```python
# Keep-alive ping (run as a daily cron or on app startup)
from qdrant_client import QdrantClient
client = QdrantClient(url=os.environ["QDRANT_URL"], api_key=os.environ["QDRANT_API_KEY"])
client.get_collections()  # any API call resets the inactivity timer
```

---

## Supabase Free Tier

| Limit | Value |
|-------|-------|
| Database | 500 MB Postgres |
| Storage | 1 GB |
| Bandwidth | 5 GB |
| Edge Functions | 500K invocations/mo |
| Auth / MAU | 50,000 MAU |
| Realtime connections | 200 concurrent |
| Row Level Security | ✓ (same as paid) |
| Project pause | Pauses after 1 week inactivity |

**Notes:**
- Project pauses after 1 week of inactivity (cold start ~30 sec on first request) — fine for dev
- All RLS policies, storage policies, auth features are identical to paid
- Upgrade to Pro ($25/mo) only when you have real users and need uptime guarantees
- Keep-alive: any DB query resets the inactivity timer

---

## Free-Tier Architecture Changes

### Model Selection (Free Path)

| Task | Free Model | Paid Upgrade |
|------|-----------|--------------|
| Document extraction | Gemini 2.5 Flash (free) | Gemini 2.5 Flash (paid) |
| Chat Q&A | Gemini 2.5 Flash (free) | Claude Sonnet 4.6 |
| Radiology / multimodal | Gemini 2.5 Flash (free, lower accuracy) | Gemini 2.5 Pro |
| Embeddings | `text-embedding-004` (free) or BGE-large local | `text-embedding-004` (paid) |
| Background classification | Gemini 2.5 Flash-Lite (free, higher RPM) | Same |

**Note:** On the free tier, drop Claude Sonnet 4.6 and use Gemini 2.5 Flash for everything. The quality difference is meaningful (Claude is more conservative and nuanced for medical Q&A) but Gemini 2.5 Flash is genuinely capable for an MVP.

### Updated `.env.example` (Free Stack)

```bash
# Gemini (free: Google AI Studio, paid: same key with billing enabled)
GOOGLE_API_KEY=your-ai-studio-key          # from aistudio.google.com/apikey

# OpenRouter (optional fallback — free account at openrouter.ai)
OPENROUTER_API_KEY=sk-or-v1-...

# Supabase (free tier)
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_KEY=your-service-role-key
SUPABASE_ANON_KEY=your-anon-key

# Qdrant Cloud (free tier) — or omit for local Chroma in dev
QDRANT_URL=https://your-cluster.qdrant.io
QDRANT_API_KEY=your-qdrant-api-key

# JWT
JWT_SECRET_KEY=generate-with-openssl-rand-hex-32
JWT_ALGORITHM=HS256

# Environment flag
ENV=development  # switches vector DB: "development" → Chroma, "production" → Qdrant
```

### Updated `pipeline.py` (Free Stack with Chroma/Qdrant Switch)

```python
import os
from llama_index.llms.google_genai import GoogleGenAI
from llama_index.embeddings.google_genai import GoogleGenAIEmbedding

def build_pipeline(user_id: str):
    llm = GoogleGenAI(
        model="gemini-2.5-flash",
        api_key=os.environ["GOOGLE_API_KEY"]
    )
    embed_model = GoogleGenAIEmbedding(
        model_name="models/text-embedding-004",
        api_key=os.environ["GOOGLE_API_KEY"]
    )

    if os.environ.get("ENV") == "production":
        # Qdrant Cloud free tier
        from qdrant_client import QdrantClient
        from llama_index.vector_stores.qdrant import QdrantVectorStore
        qdrant = QdrantClient(
            url=os.environ["QDRANT_URL"],
            api_key=os.environ["QDRANT_API_KEY"]
        )
        vector_store = QdrantVectorStore(
            client=qdrant,
            collection_name="medical_records",
            filters={"user_id": user_id}
        )
    else:
        # Chroma local (dev)
        import chromadb
        from llama_index.vector_stores.chroma import ChromaVectorStore
        chroma = chromadb.PersistentClient(path="./chroma_db")
        collection = chroma.get_or_create_collection(f"user_{user_id}")
        vector_store = ChromaVectorStore(chroma_collection=collection)

    return llm, embed_model, vector_store
```

---

## Updated Monthly Cost (Free Stack)

### Dev / Solo Testing: $0/month

| Service | Cost |
|---------|------|
| Gemini API (free tier) | $0 |
| Supabase free tier | $0 |
| Qdrant Cloud free tier | $0 |
| OpenRouter free models | $0 |
| Local Chroma (dev) | $0 |
| **Total** | **$0** |

### Early Beta (~50 users, light usage): ~$5–20/month

| Service | Cost |
|---------|------|
| Gemini API (paid, low volume) | ~$5–10 (usage-based, no subscription) |
| Supabase free tier | $0 (until >500MB or >50K MAU) |
| Qdrant Cloud free tier | $0 (until >1M vectors) |
| Railway (backend hosting) | $5 (Starter plan) |
| **Total** | **~$10–15/mo** |

### When to Upgrade

| Trigger | Upgrade |
|---------|---------|
| Gemini free RPD hit daily (250 req/day) | Enable billing on Google AI Cloud — usage-based |
| Real user data / HIPAA concern | Vertex AI (Gemini) + Anthropic Bedrock (Claude) |
| >1M vectors in Qdrant | Qdrant Cloud $25/mo (4M vectors) |
| >500MB Supabase DB | Supabase Pro $25/mo |
| Need Claude for better Q&A quality | Add `ANTHROPIC_API_KEY` — Claude Sonnet 4.6 |

---

## Data Privacy Warning

**⚠️ Google AI Studio (free tier) may use your data to improve Google's models.**

For an MVP with your own test documents: fine.
For real user health data: use Google AI API with billing enabled (data not used for training) or Vertex AI.

OpenRouter free models have similar training data terms — do not use with real patient health records.

**Safe zero-cost path with real data:** Self-hosted LLM (Ollama + Llama 3.3 70B locally) + BGE-large embeddings + local Chroma. No data leaves your machine.

---

## Connections

- [[wiki/healthrecords-ai-app/backend-ai-research]] — full paid pricing comparison and HIPAA path
- [[wiki/healthrecords-ai-app/architecture]] — main architecture (updated to reference this page)

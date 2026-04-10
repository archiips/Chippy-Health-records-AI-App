# Chippy — Health Records AI App

**Tags:** #project #medtech #ios #swift #fastapi #gemini #llamaindex
**Related:** [[wiki/project-ideas/top-picks]], [[wiki/medtech-ai/index]], [[wiki/ai-agents-fundamentals/index]]

## Pages

- [[wiki/healthrecords-ai-app/product-document]] — Full PRD: problem, features, user stories, monetization, risks
- [[wiki/healthrecords-ai-app/architecture]] — Full technical architecture: iOS, FastAPI, LlamaIndex, Qdrant, Supabase
- [[wiki/healthrecords-ai-app/swift-ios-research]] — Deep dive: VisionKit, PDFKit, HealthKit, SwiftUI patterns, SSE streaming
- [[wiki/healthrecords-ai-app/backend-ai-research]] — Gemini vs Claude, pricing, HIPAA, LlamaIndex integration, chunking strategy, Qdrant multitenancy
- [[wiki/healthrecords-ai-app/free-stack]] — $0/month MVP stack: Gemini free tier, OpenRouter, Chroma, Qdrant Cloud free, Supabase free

## Stack

| Layer | Technology |
|-------|-----------|
| iOS Frontend | Swift + SwiftUI + SwiftData |
| Document Scan | VisionKit (VNDocumentCameraViewController) |
| PDF Handling | PDFKit + Vision OCR |
| Health Data | HealthKit (FHIR clinical records + vitals) |
| Backend | FastAPI (Python) |
| AI Orchestration | LlamaIndex |
| LLM (extraction) | Gemini 2.5 Flash — free tier (250 RPD) or paid |
| LLM (chat Q&A) | Gemini 2.5 Flash (free) → Claude Sonnet 4.6 (paid upgrade) |
| Embeddings | `text-embedding-004` (free 1,500/day) or BGE-large (self-hosted) |
| Vector DB | Chroma (local/dev, free) → Qdrant Cloud (free tier, prod) |
| Database | Supabase (Postgres) |
| File Storage | Supabase Storage |
| Auth | Supabase Auth + JWT |

## 8-Week Build Plan

| Sprint | Weeks | Focus |
|--------|-------|-------|
| 1 | 1–2 | Auth, Supabase schema, iOS project + upload |
| 2 | 3–4 | Document pipeline (extract → embed → Qdrant) |
| 3 | 5–6 | RAG chat + document explainer + SSE streaming |
| 4 | 7–8 | Timeline, Face ID, onboarding, TestFlight |

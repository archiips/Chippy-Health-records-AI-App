"""
Document ingestion pipeline — Sprint 2.

Flow:
  1. Fetch document record from Supabase (get file_path, ocr_text, mime_type)
  2. Download file bytes from Supabase Storage
  3. Extract full text (PyMuPDF for PDF; fall back to iOS OCR text for images)
  4. Classify document type with Gemini (fast, cheap call on first 500 chars)
  5. Chunk text with document-type-aware strategy (LlamaIndex)
  6. Embed chunks (text-embedding-004 via GoogleGenAIEmbedding)
  7. Index into Chroma (dev) / Qdrant (prod)
  8. Structured extraction via Gemini 2.5 Flash → analysis_results row
  9. Create health_events rows from extracted events
 10. Update document status → "complete" (or "failed" on error)
"""

import json
import traceback
from io import BytesIO

import fitz  # PyMuPDF
from google import genai
from google.genai import types as genai_types
from app.ai.chunking import chunk_document
from app.ai.prompts import CLASSIFICATION_PROMPT, EXTRACTION_SYSTEM_PROMPT
from app.ai.vector_store import index_nodes
from app.core.config import settings
from app.core.supabase_client import supabase

# ── Gemini client — lazy init so import works without API key ─────────────────
_FLASH_MODEL = "gemini-2.5-flash"       # classification + extraction (20 req/day free)
_EMBED_MODEL = "gemini-embedding-001"   # embeddings (3072 dims)

_IMAGE_MIME_TYPES = {"image/jpeg", "image/png", "image/heic", "image/heif"}
_gemini: genai.Client | None = None


def _get_gemini() -> genai.Client:
    global _gemini
    if _gemini is None:
        _gemini = genai.Client(api_key=settings.google_api_key)
    return _gemini


def _embed_texts(texts: list[str]) -> list[list[float]]:
    """Embed a list of texts using gemini-embedding-001 (3072 dims)."""
    result = _get_gemini().models.embed_content(
        model=_EMBED_MODEL,
        contents=texts,
    )
    return [list(e.values) for e in result.embeddings]

# ── Document type → Supabase document_type string ────────────────────────────
_DOC_TYPE_MAP = {
    "lab_result": "lab_result",
    "radiology": "radiology",
    "discharge_summary": "discharge_summary",
    "clinical_note": "clinical_note",
    "insurance": "insurance",
    "prescription": "prescription",
    "other": "other",
}


# ─────────────────────────────────────────────────────────────────────────────
# Public entry point
# ─────────────────────────────────────────────────────────────────────────────

def ingest(document_id: str, user_id: str) -> None:
    """
    Full ingestion pipeline. Called by FastAPI BackgroundTasks (sync thread).
    Updates document status to "complete" or "failed" when done.
    """
    try:
        _run_pipeline(document_id, user_id)
        supabase.table("documents").update({"status": "complete"}).eq("id", document_id).execute()
    except Exception:
        error_msg = traceback.format_exc()
        print(f"[pipeline] FAILED document={document_id}\n{error_msg}")
        supabase.table("documents").update({
            "status": "failed",
            "error_message": error_msg[-1000:],  # store last 1000 chars
        }).eq("id", document_id).execute()


# ─────────────────────────────────────────────────────────────────────────────
# Internal steps
# ─────────────────────────────────────────────────────────────────────────────

def _run_pipeline(document_id: str, user_id: str) -> None:
    # 1. Fetch document metadata
    result = (
        supabase.table("documents")
        .select("file_path, ocr_text, mime_type, filename")
        .eq("id", document_id)
        .eq("user_id", user_id)
        .single()
        .execute()
    )
    doc_meta = result.data
    if not doc_meta:
        raise ValueError(f"Document {document_id} not found")

    # 2. Download file from Supabase Storage
    file_bytes: bytes = supabase.storage.from_("medical-documents").download(doc_meta["file_path"])

    mime_type = doc_meta["mime_type"]
    ocr_text = doc_meta.get("ocr_text") or ""

    if mime_type in _IMAGE_MIME_TYPES:
        # ── Image path: use iOS OCR text + Flash (same as PDF path)
        text = ocr_text
        if not text.strip():
            raise ValueError("No OCR text available for image document")
        doc_type = _classify_document_type(text)
        extraction = _extract_structured(text)
    else:
        # ── PDF path: PyMuPDF text + gemini-2.5-flash (classify + extract)
        text = _extract_text(file_bytes, mime_type, ocr_text)
        if not text.strip():
            raise ValueError("No text could be extracted from document")
        doc_type = _classify_document_type(text)
        extraction = _extract_structured(text)

    # Update document_type in DB
    supabase.table("documents").update({"document_type": doc_type}).eq("id", document_id).execute()

    if not text.strip():
        raise ValueError("No text available for embedding")

    # Chunk text
    nodes = chunk_document(text, doc_type)
    if not nodes:
        raise ValueError("Chunking produced no nodes")

    # Embed chunks
    texts_to_embed = [node.get_content() for node in nodes]
    embeddings = _embed_texts(texts_to_embed)

    # Index into vector store
    index_nodes(nodes, embeddings, user_id=user_id, document_id=document_id)

    # Reject empty extractions — better to be failed+retryable than complete with no data
    has_content = (
        extraction.get("summary") or
        extraction.get("lab_values") or
        extraction.get("diagnoses") or
        extraction.get("medications") or
        extraction.get("key_findings")
    )
    if not has_content:
        raise RuntimeError("Extraction returned no usable content — Gemini may be over quota. Please retry.")

    # Save analysis_results
    _save_analysis(document_id, user_id, extraction)

    # Create health_events
    _save_health_events(document_id, user_id, extraction.get("health_events", []))


def _extract_text(file_bytes: bytes, mime_type: str, ocr_fallback: str) -> str:
    """Extract text from PDF using PyMuPDF; fall back to iOS OCR for images."""
    if mime_type == "application/pdf":
        try:
            doc = fitz.open(stream=BytesIO(file_bytes), filetype="pdf")
            pages = [page.get_text() for page in doc]
            text = "\n\n".join(pages).strip()
            doc.close()
            if text:
                return text
        except Exception as e:
            print(f"[pipeline] PyMuPDF extraction failed: {e}")

    # Images or failed PDF: use OCR text extracted on-device by iOS
    return ocr_fallback


def _classify_document_type(text: str) -> str:
    """Quick Gemini call to classify document type from first 500 chars."""
    import time
    prompt = CLASSIFICATION_PROMPT.format(text=text[:500])
    last_exc: Exception | None = None
    for attempt in range(3):
        try:
            response = _get_gemini().models.generate_content(
                model=_FLASH_MODEL,
                contents=prompt,
                config=genai_types.GenerateContentConfig(
                    temperature=0,
                    max_output_tokens=20,
                ),
            )
            result = response.text.strip().lower()
            return result if result in _DOC_TYPE_MAP else "other"
        except Exception as e:
            last_exc = e
            exc_str = str(e)
            if "429" in exc_str and "RESOURCE_EXHAUSTED" in exc_str:
                # Daily quota exhausted — no point retrying
                print(f"[pipeline] Classification quota exhausted — skip retries")
                break
            elif "503" in exc_str or "UNAVAILABLE" in exc_str:
                wait = 2 ** attempt
                print(f"[pipeline] Classification 503, retry {attempt+1}/3 in {wait}s")
                time.sleep(wait)
            else:
                break
    print(f"[pipeline] Classification failed: {last_exc}")
    return "other"


def _extract_structured(text: str) -> dict:
    """
    Gemini 2.5 Flash structured extraction.
    Returns parsed JSON dict. Raises on total failure.
    """
    import time
    truncated = text[:30_000]

    last_exc: Exception | None = None
    for attempt in range(3):
        try:
            response = _get_gemini().models.generate_content(
                model=_FLASH_MODEL,
                contents=[
                    genai_types.Content(
                        role="user",
                        parts=[genai_types.Part(text=truncated)],
                    )
                ],
                config=genai_types.GenerateContentConfig(
                    system_instruction=EXTRACTION_SYSTEM_PROMPT,
                    temperature=0.1,
                    max_output_tokens=4096,
                    response_mime_type="application/json",
                ),
            )
            raw = response.text.strip()
            # Strip markdown fences if model ignores response_mime_type hint
            if raw.startswith("```"):
                raw = raw.split("```")[1]
                if raw.startswith("json"):
                    raw = raw[4:]
            return json.loads(raw)
        except Exception as e:
            last_exc = e
            exc_str = str(e)
            if "429" in exc_str and "RESOURCE_EXHAUSTED" in exc_str:
                # Daily quota exhausted — fail immediately, no retries
                print(f"[pipeline] Extraction quota exhausted — skip retries")
                raise
            elif "503" in exc_str or "UNAVAILABLE" in exc_str:
                wait = 2 ** attempt
                print(f"[pipeline] Extraction 503, retry {attempt+1}/3 in {wait}s")
                time.sleep(wait)
            else:
                raise
    raise last_exc


def _save_analysis(document_id: str, user_id: str, extraction: dict) -> None:
    """Upsert analysis_results row."""
    supabase.table("analysis_results").upsert(
        {
            "document_id": document_id,
            "user_id": user_id,
            "summary": extraction.get("summary", ""),
            "lab_values": extraction.get("lab_values", []),
            "diagnoses": extraction.get("diagnoses", []),
            "medications": extraction.get("medications", []),
            "key_findings": extraction.get("key_findings", []),
        },
        on_conflict="document_id",
    ).execute()


def _save_health_events(document_id: str, user_id: str, events: list[dict]) -> None:
    """Insert health_events rows. Skip events with missing required fields."""
    if not events:
        return

    rows = []
    for evt in events:
        title = evt.get("title", "").strip()
        category = evt.get("category", "").strip()
        if not title or not category:
            continue

        row = {
            "document_id": document_id,
            "user_id": user_id,
            "title": title,
            "category": category,
            "summary": evt.get("description", ""),
        }
        date_str = evt.get("event_date", "").strip()
        if date_str:
            row["event_date"] = date_str

        rows.append(row)

    if rows:
        supabase.table("health_events").insert(rows).execute()

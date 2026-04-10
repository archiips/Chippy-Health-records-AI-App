"""
Background ingestion tasks.

FastAPI BackgroundTasks runs these in a thread pool — keep them synchronous.
Sprint 2: real pipeline (PyMuPDF → LlamaIndex → Gemini → Qdrant/Chroma).
"""

from app.ai.pipeline import ingest


def ingest_document(document_id: str, user_id: str) -> None:
    """Enqueued by POST /documents/upload and POST /documents/{id}/retry."""
    ingest(document_id, user_id)

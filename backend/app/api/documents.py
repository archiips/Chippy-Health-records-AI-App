import asyncio
import json
import uuid
from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Request, UploadFile, Form, status
from fastapi.responses import StreamingResponse

from app.background.tasks import ingest_document
from app.core.auth import get_current_user
from app.core.supabase_client import supabase
from app.models.schemas import DocumentResponse, DocumentStatusResponse, SignedUrlResponse, UploadResponse

router = APIRouter()

ALLOWED_MIME_TYPES = {
    "application/pdf",
    "image/jpeg",
    "image/png",
    "image/heic",
    "image/heif",
}

CurrentUser = Annotated[str, Depends(get_current_user)]


@router.post("/upload", response_model=UploadResponse, status_code=status.HTTP_201_CREATED)
def upload_document(
    file: UploadFile,
    background_tasks: BackgroundTasks,
    user_id: CurrentUser,
    ocr_text: str = Form(default=""),
):
    if file.content_type not in ALLOWED_MIME_TYPES:
        raise HTTPException(
            status_code=status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            detail=f"Unsupported file type '{file.content_type}'. Allowed: PDF, JPEG, PNG, HEIC.",
        )

    document_id = str(uuid.uuid4())
    file_bytes = file.file.read()
    file_size = len(file_bytes)
    storage_path = f"{user_id}/{document_id}/{file.filename}"

    # Upload to Supabase Storage
    try:
        supabase.storage.from_("medical-documents").upload(
            path=storage_path,
            file=file_bytes,
            file_options={"content-type": file.content_type},
        )
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=f"Storage upload failed: {e}")

    # Insert document row
    supabase.table("documents").insert({
        "id": document_id,
        "user_id": user_id,
        "filename": file.filename,
        "file_path": storage_path,
        "file_size": file_size,
        "mime_type": file.content_type,
        "ocr_text": ocr_text or None,
        "status": "processing",
    }).execute()

    # Enqueue ingestion (Sprint 2: replace stub with real pipeline)
    background_tasks.add_task(ingest_document, document_id, user_id)

    return UploadResponse(document_id=document_id)


@router.get("", response_model=list[DocumentResponse])
def list_documents(user_id: CurrentUser):
    result = (
        supabase.table("documents")
        .select("*, analysis_results(*)")
        .eq("user_id", user_id)
        .order("created_at", desc=True)
        .execute()
    )

    docs = []
    for row in result.data:
        analysis = row.pop("analysis_results", None)
        docs.append(DocumentResponse(
            **row,
            analysis_result=analysis[0] if analysis else None,
        ))
    return docs


@router.get("/{document_id}", response_model=DocumentResponse)
def get_document(document_id: str, user_id: CurrentUser):
    result = (
        supabase.table("documents")
        .select("*, analysis_results(*)")
        .eq("id", document_id)
        .eq("user_id", user_id)
        .single()
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")

    row = result.data
    analysis = row.pop("analysis_results", None)
    # Supabase returns a dict (not list) for one-to-one FK relationships
    if isinstance(analysis, list):
        analysis_result = analysis[0] if analysis else None
    else:
        analysis_result = analysis  # already a single dict or None
    return DocumentResponse(**row, analysis_result=analysis_result)


@router.delete("/{document_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_document(document_id: str, user_id: CurrentUser):
    # Verify ownership + get storage path
    result = (
        supabase.table("documents")
        .select("file_path")
        .eq("id", document_id)
        .eq("user_id", user_id)
        .single()
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")

    # Delete from storage first (so we don't lose the path)
    try:
        supabase.storage.from_("medical-documents").remove([result.data["file_path"]])
    except Exception:
        pass  # Don't block DB delete if storage delete fails — log in prod

    # Delete DB row (cascades to analysis_results, health_events)
    supabase.table("documents").delete().eq("id", document_id).eq("user_id", user_id).execute()


@router.get("/{document_id}/url", response_model=SignedUrlResponse)
def get_signed_url(document_id: str, user_id: CurrentUser):
    result = (
        supabase.table("documents")
        .select("file_path")
        .eq("id", document_id)
        .eq("user_id", user_id)
        .single()
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")

    signed = supabase.storage.from_("medical-documents").create_signed_url(
        path=result.data["file_path"],
        expires_in=3600,
    )

    url = signed.get("signedURL") or signed.get("signed_url") or signed.get("data", {}).get("signedUrl", "")
    if not url:
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Could not generate signed URL")

    return SignedUrlResponse(url=url)


@router.get("/{document_id}/status", response_model=DocumentStatusResponse)
def get_document_status(document_id: str, user_id: CurrentUser):
    result = (
        supabase.table("documents")
        .select("id, status, document_type, error_message")
        .eq("id", document_id)
        .eq("user_id", user_id)
        .single()
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")

    row = result.data
    return DocumentStatusResponse(
        document_id=row["id"],
        status=row["status"],
        document_type=row.get("document_type"),
        error_message=row.get("error_message"),
    )


@router.post("/{document_id}/retry", response_model=UploadResponse)
def retry_ingestion(document_id: str, background_tasks: BackgroundTasks, user_id: CurrentUser):
    result = (
        supabase.table("documents")
        .select("id, status")
        .eq("id", document_id)
        .eq("user_id", user_id)
        .single()
        .execute()
    )

    if not result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")

    if result.data["status"] != "failed":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Only failed documents can be retried")

    supabase.table("documents").update({"status": "processing", "error_message": None}).eq("id", document_id).execute()
    background_tasks.add_task(ingest_document, document_id, user_id)

    return UploadResponse(document_id=document_id)


@router.post("/{document_id}/explain")
async def explain_document(document_id: str, request: Request, user_id: CurrentUser):
    """
    Stream a plain-language explanation of the document via SSE.
    Caches the result in analysis_results.explainer_text on first call.
    """
    # Fetch document + analysis
    doc_result = (
        supabase.table("documents")
        .select("id, filename, status, ocr_text, file_path, mime_type")
        .eq("id", document_id)
        .eq("user_id", user_id)
        .single()
        .execute()
    )
    if not doc_result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")

    doc = doc_result.data
    if doc["status"] != "complete":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Document analysis not complete")

    analysis_result = (
        supabase.table("analysis_results")
        .select("id, explainer_text, summary, diagnoses, medications, key_findings, lab_values")
        .eq("document_id", document_id)
        .single()
        .execute()
    )
    analysis = analysis_result.data

    # Return cached explanation if available
    if analysis and analysis.get("explainer_text"):
        cached = analysis["explainer_text"]

        async def cached_stream():
            # Stream in chunks so iOS SSE parser handles it identically
            chunk_size = 200
            for i in range(0, len(cached), chunk_size):
                chunk = cached[i:i + chunk_size].replace("\n", "\\n")
                yield f"data: {chunk}\n\n"
                await asyncio.sleep(0)
            yield "data: [DONE]\n\n"

        return StreamingResponse(cached_stream(), media_type="text/event-stream",
                                  headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})

    # Build document text for explanation
    from app.ai.pipeline import _extract_text
    from io import BytesIO

    try:
        file_bytes: bytes = supabase.storage.from_("medical-documents").download(doc["file_path"])
        full_text = _extract_text(file_bytes, doc["mime_type"], doc.get("ocr_text") or "")
    except Exception:
        full_text = doc.get("ocr_text") or ""

    if not full_text.strip():
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail="No text available to explain")

    from app.ai.prompts import EXPLAINER_PROMPT

    truncated = full_text[:20_000]

    async def explain_stream():
        from app.ai.gemini_client import stream_completion

        full_response: list[str] = []
        try:
            async for piece in stream_completion(
                system=EXPLAINER_PROMPT,
                user=truncated,
                max_tokens=2048,
                temperature=0.3,
            ):
                if await request.is_disconnected():
                    break
                full_response.append(piece)
                safe = piece.replace("\n", "\\n")
                yield f"data: {safe}\n\n"
        except Exception as e:
            yield f"data: {json.dumps({'error': str(e)})}\n\n"
        finally:
            yield "data: [DONE]\n\n"
            # Cache the result
            if full_response and analysis:
                completed = "".join(full_response)
                supabase.table("analysis_results").update(
                    {"explainer_text": completed}
                ).eq("id", analysis["id"]).execute()

    return StreamingResponse(explain_stream(), media_type="text/event-stream",
                              headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"})

"""
Chat API — Sprint 3.

POST /chat/stream  — SSE streaming RAG chat
GET  /chat/history — last 50 messages
DELETE /chat/history — clear history
"""

import asyncio
import json

from typing import Annotated

from fastapi import APIRouter, Depends, Request
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

from app.core.auth import get_current_user
from app.services.chat_service import clear_chat_history, get_chat_history, stream_chat

CurrentUser = Annotated[str, Depends(get_current_user)]

router = APIRouter(prefix="/chat", tags=["chat"])


class ChatRequest(BaseModel):
    query: str = Field(..., min_length=1, max_length=2000)
    document_ids: list[str] | None = None


@router.post("/stream")
async def stream_chat_endpoint(body: ChatRequest, request: Request, user_id: CurrentUser):
    """
    Stream a RAG chat response as SSE.
    Format: `data: {chunk}\\n\\n`, terminated by `data: [DONE]\\n\\n`
    """
    async def event_generator():
        try:
            async for chunk in stream_chat(body.query, user_id, body.document_ids):
                if await request.is_disconnected():
                    break
                # Escape newlines so each SSE message stays on one logical line
                safe = chunk.replace("\n", "\\n")
                yield f"data: {safe}\n\n"
                await asyncio.sleep(0)  # yield control to event loop
        except Exception as e:
            error_payload = json.dumps({"error": str(e)})
            yield f"data: {error_payload}\n\n"
        finally:
            yield "data: [DONE]\n\n"

    return StreamingResponse(
        event_generator(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",  # disable nginx buffering
        },
    )


@router.get("/history")
def chat_history(user_id: CurrentUser):
    return get_chat_history(user_id)


@router.delete("/history", status_code=204)
def delete_chat_history(user_id: CurrentUser):
    clear_chat_history(user_id)

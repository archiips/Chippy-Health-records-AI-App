"""
Chat service — Sprint 3.

Streams RAG responses and persists messages to chat_messages table.
"""

from typing import AsyncGenerator

from app.ai.query_engine import stream_rag_response
from app.core.supabase_client import supabase


async def stream_chat(
    query: str,
    user_id: str,
    document_ids: list[str] | None = None,
) -> AsyncGenerator[str, None]:
    """
    Async generator yielding text chunks for a RAG chat query.
    Persists both the user message and the completed assistant response.
    """
    # Persist user message immediately
    supabase.table("chat_messages").insert({
        "user_id": user_id,
        "role": "user",
        "content": query,
        "source_document_ids": document_ids or [],
    }).execute()

    # Stream and accumulate the response
    full_response: list[str] = []
    async for chunk in stream_rag_response(query, user_id, document_ids):
        full_response.append(chunk)
        yield chunk

    # Persist completed assistant response
    if full_response:
        supabase.table("chat_messages").insert({
            "user_id": user_id,
            "role": "assistant",
            "content": "".join(full_response),
            "source_document_ids": document_ids or [],
        }).execute()


def get_chat_history(user_id: str, limit: int = 50) -> list[dict]:
    result = (
        supabase.table("chat_messages")
        .select("*")
        .eq("user_id", user_id)
        .order("created_at", desc=False)
        .limit(limit)
        .execute()
    )
    return result.data or []


def clear_chat_history(user_id: str) -> None:
    supabase.table("chat_messages").delete().eq("user_id", user_id).execute()

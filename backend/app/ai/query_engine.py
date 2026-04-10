"""
RAG query engine — Sprint 3.

Builds a LlamaIndex query engine over the user's indexed documents
(Chroma in dev, Qdrant in prod), filtered strictly to their user_id.
"""

from typing import AsyncGenerator

from llama_index.core import VectorStoreIndex
from llama_index.core.vector_stores import MetadataFilter, MetadataFilters, FilterOperator

from app.ai.prompts import RAG_SYSTEM_PROMPT
from app.ai.vector_store import get_vector_store, COLLECTION_NAME


def _build_index(user_id: str, document_ids: list[str] | None = None) -> VectorStoreIndex:
    """
    Build a VectorStoreIndex scoped to the given user (and optionally specific documents).
    Document embeddings are pre-computed and stored — the embed model here is only used
    to embed the query at retrieval time, so it must be the real model (not MockEmbedding).
    """
    from llama_index.embeddings.google_genai import GoogleGenAIEmbedding
    from app.core.config import settings

    store = get_vector_store()

    filters_list = [
        MetadataFilter(key="user_id", value=user_id, operator=FilterOperator.EQ)
    ]
    if document_ids:
        filters_list.append(
            MetadataFilter(key="document_id", value=document_ids, operator=FilterOperator.IN)
        )

    filters = MetadataFilters(filters=filters_list)

    embed_model = GoogleGenAIEmbedding(
        model_name="gemini-embedding-001",
        api_key=settings.google_api_key,
        output_dimensionality=3072,
    )

    return VectorStoreIndex.from_vector_store(
        vector_store=store,
        embed_model=embed_model,
    )


async def stream_rag_response(
    query: str,
    user_id: str,
    document_ids: list[str] | None = None,
) -> AsyncGenerator[str, None]:
    """
    Async generator that yields text chunks for the given query.
    Retrieves top-5 chunks from the user's documents and streams a Gemini response.
    """
    print(f"[rag] building index for user={user_id} doc_ids={document_ids}")
    try:
        index = _build_index(user_id, document_ids)
    except Exception as e:
        print(f"[rag] _build_index failed: {type(e).__name__}: {e}")
        raise

    retriever = index.as_retriever(similarity_top_k=5)
    print(f"[rag] retrieving for query={query!r:.60}")
    try:
        nodes = retriever.retrieve(query)
    except Exception as e:
        print(f"[rag] retriever.retrieve failed: {type(e).__name__}: {e}")
        raise
    print(f"[rag] retrieved {len(nodes)} nodes")

    if not nodes:
        yield "I don't see any relevant information in your uploaded documents."
        yield "\n\nThis is for informational purposes only. Please consult your doctor for medical advice."
        return

    # Build context from retrieved chunks
    context_parts = []
    for node in nodes:
        doc_id = node.metadata.get("document_id", "unknown")
        context_parts.append(f"[Document: {doc_id}]\n{node.get_content()}")
    context = "\n\n---\n\n".join(context_parts)

    from app.ai.gemini_client import stream_completion

    async for chunk in stream_completion(
        system=RAG_SYSTEM_PROMPT,
        user=f"Retrieved document chunks:\n{context}\n\nUser question: {query}",
        max_tokens=1024,
        temperature=0.2,
    ):
        yield chunk

"""
Vector store abstraction.

Dev  (ENV=development) → local ChromaDB (no config needed)
Prod (ENV=production)  → Qdrant Cloud (requires QDRANT_URL + QDRANT_API_KEY)

Single collection "medical_records" with user_id payload filtering —
never use per-user collections (breaks at scale).
"""

import chromadb
from llama_index.core.schema import TextNode
from llama_index.vector_stores.chroma import ChromaVectorStore
from llama_index.vector_stores.qdrant import QdrantVectorStore

from app.core.config import settings

COLLECTION_NAME = "medical_records"


def _get_chroma_store() -> ChromaVectorStore:
    client = chromadb.PersistentClient(path="./chroma_db")
    collection = client.get_or_create_collection(COLLECTION_NAME)
    return ChromaVectorStore(chroma_collection=collection)


def _get_qdrant_store() -> QdrantVectorStore:
    from qdrant_client import QdrantClient
    from qdrant_client.models import Distance, VectorParams

    client = QdrantClient(url=settings.qdrant_url, api_key=settings.qdrant_api_key)

    # Create collection if it doesn't exist (gemini-embedding-001 = 3072 dims)
    existing = [c.name for c in client.get_collections().collections]
    if COLLECTION_NAME not in existing:
        client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(size=3072, distance=Distance.COSINE),
        )

    return QdrantVectorStore(
        client=client,
        collection_name=COLLECTION_NAME,
    )


def get_vector_store():
    """Return the appropriate vector store for the current environment."""
    if settings.is_production and settings.qdrant_url:
        return _get_qdrant_store()
    return _get_chroma_store()


def index_nodes(
    nodes: list[TextNode],
    embeddings: list[list[float]],
    user_id: str,
    document_id: str,
) -> None:
    """
    Attach user_id + document_id metadata to every node, then upsert
    into the vector store with pre-computed embeddings.
    """
    store = get_vector_store()

    for node, embedding in zip(nodes, embeddings):
        node.metadata["user_id"] = user_id
        node.metadata["document_id"] = document_id
        node.embedding = embedding

    store.add(nodes)


def delete_document_vectors(document_id: str, user_id: str) -> None:
    """
    Remove all vector chunks belonging to a document.
    Called when the user deletes a document.
    """
    store = get_vector_store()

    if isinstance(store, ChromaVectorStore):
        # ChromaDB: delete by metadata filter
        store.delete(
            filters={"document_id": document_id, "user_id": user_id}
        )
    elif isinstance(store, QdrantVectorStore):
        from qdrant_client.models import FieldCondition, Filter, MatchValue
        store._client.delete(
            collection_name=COLLECTION_NAME,
            points_selector=Filter(
                must=[
                    FieldCondition(key="document_id", match=MatchValue(value=document_id)),
                    FieldCondition(key="user_id", match=MatchValue(value=user_id)),
                ]
            ),
        )

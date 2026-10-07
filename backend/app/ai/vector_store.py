"""
Vector store abstraction.

Dev  (ENV=development) → local ChromaDB (no config needed)
Prod (ENV=production)  → Qdrant Cloud (requires QDRANT_URL + QDRANT_API_KEY)

Single collection "medical_records" with user_id payload filtering —
never use per-user collections (breaks at scale).
"""

import json
import chromadb
from llama_index.core.schema import TextNode, NodeRelationship, RelatedNodeInfo
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
    from qdrant_client.models import Distance, VectorParams, PayloadSchemaType, KeywordIndexParams, KeywordIndexType

    client = QdrantClient(url=settings.qdrant_url, api_key=settings.qdrant_api_key)

    # Create collection if it doesn't exist (gemini-embedding-001 = 3072 dims)
    existing = [c.name for c in client.get_collections().collections]
    if COLLECTION_NAME not in existing:
        client.create_collection(
            collection_name=COLLECTION_NAME,
            vectors_config=VectorParams(size=3072, distance=Distance.COSINE),
        )

    client.create_payload_index(
        collection_name=COLLECTION_NAME,
        field_name="user_id",
        field_schema=KeywordIndexParams(type=KeywordIndexType.KEYWORD, is_tenant=True),
        wait=True,
    )
    client.create_payload_index(collection_name=COLLECTION_NAME, field_name="document_id",
                                field_schema=PayloadSchemaType.KEYWORD, wait=True)
    return QdrantVectorStore(
        client=client,
        collection_name=COLLECTION_NAME,
    )


def get_vector_store():
    """Return the appropriate vector store for the current environment."""
    if settings.is_production:
        if not settings.qdrant_url:
            raise ValueError("Production requires QDRANT_URL")
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
    if len(nodes) != len(embeddings):
        raise ValueError("Every node must have an embedding")
    store = get_vector_store()

    for node, embedding in zip(nodes, embeddings):
        node.metadata["user_id"] = user_id
        node.metadata["document_id"] = document_id
        # LlamaIndex reserves document_id/ref_doc_id in adapter payloads and
        # derives them from SOURCE. Keep that source equal to our record UUID.
        node.relationships[NodeRelationship.SOURCE] = RelatedNodeInfo(node_id=document_id)
        node.embedding = embedding

    store.add(nodes)


def delete_document_vectors(document_id: str, user_id: str) -> None:
    """
    Remove all vector chunks belonging to a document.
    Called when the user deletes a document.
    """
    _delete_vectors(user_id, document_id)


def delete_user_vectors(user_id: str) -> None:
    """Also removes orphan chunks left by interrupted ingestion."""
    _delete_vectors(user_id)


def _delete_vectors(user_id: str, document_id: str | None = None) -> None:
    if not user_id:
        raise ValueError("A user scope is required for vector deletion")
    store = get_vector_store()
    fields = {"user_id": user_id}
    if document_id is not None:
        fields["document_id"] = document_id

    if isinstance(store, ChromaVectorStore):
        # ChromaDB: delete by metadata filter
        # The installed LlamaIndex adapter passes ids=[] to delete_nodes,
        # which current Chroma rejects. Delete by the actual scoped payload.
        conditions = [{key: {"$eq": value}} for key, value in fields.items()]
        where = {"$and": conditions} if len(conditions) > 1 else conditions[0]
        store._collection.delete(where=where)
        if document_id is not None:
            # Older builds omitted SOURCE; the adapter overwrote document_id
            # with "None" but retained the original metadata inside node JSON.
            legacy_where = {"$and": [{"user_id": {"$eq": user_id}}, {"document_id": {"$eq": "None"}}]}
            offset, legacy_ids = 0, []
            while True:
                page = store._collection.get(where=legacy_where, include=["metadatas"], limit=1000, offset=offset)
                for node_id, payload in zip(page["ids"], page["metadatas"]):
                    if _legacy_matches(payload, user_id, document_id):
                        legacy_ids.append(node_id)
                if len(page["ids"]) < 1000:
                    break
                offset += len(page["ids"])
            if legacy_ids:
                store._collection.delete(ids=legacy_ids, where={"user_id": {"$eq": user_id}})
    elif isinstance(store, QdrantVectorStore):
        from qdrant_client.models import FieldCondition, Filter, MatchValue, HasIdCondition
        store._client.delete(
            collection_name=COLLECTION_NAME,
            points_selector=Filter(
                must=[
                    FieldCondition(key=key, match=MatchValue(value=value))
                    for key, value in fields.items()
                ]
            ),
            wait=True,
        )
        if document_id is not None:
            owner = FieldCondition(key="user_id", match=MatchValue(value=user_id))
            legacy_filter = Filter(must=[owner, FieldCondition(key="document_id", match=MatchValue(value="None"))])
            offset, legacy_ids = None, []
            while True:
                page, offset = store._client.scroll(collection_name=COLLECTION_NAME,
                    scroll_filter=legacy_filter, limit=1000, offset=offset, with_payload=True, with_vectors=False)
                legacy_ids.extend(point.id for point in page if _legacy_matches(point.payload, user_id, document_id))
                if offset is None:
                    break
            if legacy_ids:
                store._client.delete(collection_name=COLLECTION_NAME,
                    points_selector=Filter(must=[owner, HasIdCondition(has_id=legacy_ids)]), wait=True)
    else:
        raise TypeError("Unsupported vector store")


def _legacy_matches(payload: dict, user_id: str, document_id: str) -> bool:
    metadata = json.loads(payload["_node_content"])["metadata"]
    if payload.get("user_id") != user_id or metadata.get("user_id") != user_id:
        raise ValueError("Legacy vector owner validation failed")
    return metadata.get("document_id") == document_id

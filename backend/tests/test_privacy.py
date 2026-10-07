"""Synthetic-only regression tests; never read .env or contact a provider."""
import asyncio
import importlib
import sys
import tempfile
import types
import unittest
import threading
from pathlib import Path
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
config = types.ModuleType("app.core.config")
config.settings = types.SimpleNamespace(
    google_api_key="unused-synthetic-key", is_production=False,
    qdrant_url="", qdrant_api_key="", jwt_secret_key="synthetic-only-secret",
    jwt_algorithm="HS256", jwt_access_token_expire_minutes=15,
    jwt_refresh_token_expire_days=30,
)
sys.modules["app.core.config"] = config
clients = types.ModuleType("app.core.supabase_client")
clients.supabase = None
clients.supabase_auth = None
sys.modules["app.core.supabase_client"] = clients

import chromadb
from fastapi import HTTPException
from llama_index.core import MockEmbedding
from llama_index.core.schema import TextNode
from llama_index.vector_stores.chroma import ChromaVectorStore
from app.ai import query_engine, vector_store
from app.api import documents, auth
original_get_vector_store = vector_store.get_vector_store


class FakeQuery:
    def __init__(self, database, table):
        self.database, self.name = database, table
        self.conditions = []
        self.operation = "select"
        self.is_single = False

    def select(self, *_): return self
    def eq(self, key, value):
        self.conditions.append((key, value))
        return self
    def single(self):
        self.is_single = True
        return self
    def delete(self):
        self.operation = "delete"
        return self
    def update(self, values):
        self.operation = "update"
        self.values = values
        return self
    def insert(self, values):
        self.operation = "insert"
        self.values = values
        return self
    def execute(self):
        rows = self.database.rows.setdefault(self.name, [])
        found = [r for r in rows if all(r.get(k) == v for k, v in self.conditions)]
        if self.operation == "delete":
            self.database.rows[self.name] = [r for r in rows if r not in found]
        elif self.operation == "update":
            for row in found: row.update(self.values)
        elif self.operation == "insert":
            rows.extend(self.values if isinstance(self.values, list) else [self.values])
        return types.SimpleNamespace(data=(found[0] if found else None) if self.is_single else found)


class FakeStorage:
    def __init__(self):
        self.paths = {"alpha/alpha-doc/report.pdf", "beta/beta-doc/report.pdf"}
        self.fail = False
    def from_(self, _): return self
    def upload(self, path, file, file_options): self.paths.add(path)
    def remove(self, paths):
        if self.fail: raise OSError("synthetic storage unavailable")
        self.paths.difference_update(paths)
    def list(self, path, options=None):
        prefix = path + "/"
        names = sorted({p[len(prefix):].split("/")[0] for p in self.paths if p.startswith(prefix)})
        rows = [{"name": name, "id": name if prefix + name in self.paths else None} for name in names]
        options = options or {}
        start = options.get("offset", 0)
        return rows[start:start + options.get("limit", 100)]


class FakeDatabase:
    def __init__(self):
        self.storage = FakeStorage()
        self.rows = {
            "documents": [
                {"id": "alpha-doc", "user_id": "alpha", "file_path": "alpha/alpha-doc/report.pdf"},
                {"id": "beta-doc", "user_id": "beta", "file_path": "beta/beta-doc/report.pdf"},
            ],
            "chat_messages": [{"user_id": "alpha"}, {"user_id": "beta"}],
        }
    def table(self, name): return FakeQuery(self, name)


class PrivacyTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="chippy-test-")
        collection = chromadb.PersistentClient(path=self.temp.name).get_or_create_collection("synthetic")
        self.store = ChromaVectorStore(chroma_collection=collection)
        self.nodes = [
            TextNode(id_="alpha-1", text="SYNTHETIC alpha selected record", metadata={"user_id":"alpha", "document_id":"alpha-doc"}, embedding=[0.5]*8),
            TextNode(id_="alpha-2", text="SYNTHETIC alpha excluded record", metadata={"user_id":"alpha", "document_id":"other-doc"}, embedding=[0.5]*8),
            TextNode(id_="beta-1", text="SYNTHETIC beta private record", metadata={"user_id":"beta", "document_id":"beta-doc"}, embedding=[0.5]*8),
        ]
        self.db = FakeDatabase()
        self.patches = [
            patch.object(vector_store, "get_vector_store", return_value=self.store),
            patch.object(query_engine, "get_vector_store", return_value=self.store),
            patch("llama_index.embeddings.google_genai.GoogleGenAIEmbedding", side_effect=lambda **_:MockEmbedding(embed_dim=8)),
            patch.object(documents, "supabase", self.db),
            patch.object(auth, "supabase", self.db),
        ]
        for p in self.patches: p.start()
        for node in self.nodes:
            vector_store.index_nodes([node], [[0.5]*8], node.metadata["user_id"], node.metadata["document_id"])

    def tearDown(self):
        for p in reversed(self.patches): p.stop()
        self.temp.cleanup()

    def test_retrieval_applies_both_owner_and_selected_documents(self):
        async def echo_context(**kwargs): yield kwargs["user"]
        async def collect():
            return "".join([part async for part in query_engine.stream_rag_response("record", "alpha", ["alpha-doc"])])
        with patch("app.ai.gemini_client.stream_completion", echo_context):
            context = asyncio.run(collect())
        self.assertIn("alpha selected record", context)
        self.assertNotIn("beta private record", context)
        self.assertNotIn("alpha excluded record", context)

    def test_document_vector_delete_preserves_other_documents_and_users(self):
        vector_store.delete_document_vectors("alpha-doc", "alpha")
        remaining = self.store._collection.get()["ids"]
        self.assertCountEqual(remaining, ["alpha-2", "beta-1"])

    def test_deleting_old_chroma_payload_recovers_document_id_without_crossing_owner(self):
        for owner in ["alpha", "beta"]:
            self.store.add([TextNode(id_=f"legacy-{owner}", text="synthetic old payload", metadata={"user_id":owner, "document_id":"legacy-doc"}, embedding=[0.5]*8)])
        self.assertEqual(self.store._collection.get(ids=["legacy-alpha"])["metadatas"][0]["document_id"], "None")
        vector_store.delete_document_vectors("legacy-doc", "alpha")
        self.assertNotIn("legacy-alpha", self.store._collection.get()["ids"])
        self.assertIn("legacy-beta", self.store._collection.get()["ids"])

    def test_delete_endpoint_removes_vectors_file_and_metadata(self):
        documents.delete_document("alpha-doc", "alpha")
        self.assertNotIn("alpha-1", self.store._collection.get()["ids"])
        self.assertIn("beta-1", self.store._collection.get()["ids"])
        self.assertEqual([r["id"] for r in self.db.rows["documents"]], ["beta-doc"])
        self.assertEqual(self.db.storage.paths, {"beta/beta-doc/report.pdf"})

    def test_failed_cleanup_keeps_metadata_for_retry(self):
        self.db.storage.fail = True
        with self.assertRaises(HTTPException) as caught:
            documents.delete_document("alpha-doc", "alpha")
        self.assertEqual(caught.exception.status_code, 503)
        self.assertIn("alpha-doc", [r["id"] for r in self.db.rows["documents"]])

    def test_untrusted_filename_cannot_change_upload_storage_scope(self):
        from io import BytesIO
        from fastapi import BackgroundTasks, UploadFile
        from starlette.datastructures import Headers
        upload = UploadFile(filename="../../beta/report.pdf", file=BytesIO(b"synthetic PDF"), headers=Headers({"content-type":"application/pdf"}))
        response = documents.upload_document(upload, BackgroundTasks(), "alpha")
        row = next(row for row in self.db.rows["documents"] if row["id"] == response.document_id)
        self.assertTrue(row["file_path"].startswith(f"alpha/{response.document_id}/"))
        self.assertNotIn("..", row["file_path"].split("/"))

    def test_corrupt_storage_reference_cannot_delete_other_owners_file(self):
        self.db.rows["documents"][0]["file_path"] = "beta/beta-doc/report.pdf"
        with self.assertRaises(HTTPException): documents.delete_document("alpha-doc", "alpha")
        self.assertIn("beta/beta-doc/report.pdf", self.db.storage.paths)
        self.assertIn("alpha-doc", [row["id"] for row in self.db.rows["documents"]])

    def test_user_cannot_delete_another_users_document(self):
        with self.assertRaises(HTTPException): documents.delete_document("beta-doc", "alpha")
        self.assertEqual(len(self.db.rows["documents"]), 2)
        self.assertEqual(self.store._collection.count(), 3)

    def test_delete_all_includes_orphan_vectors_and_preserves_other_user(self):
        self.db.storage.paths.add("alpha/no-metadata/orphan.pdf")
        auth.delete_account("alpha")
        self.assertEqual(self.store._collection.get()["ids"], ["beta-1"])
        self.assertEqual(self.db.rows["chat_messages"], [{"user_id": "beta"}])
        self.assertEqual(self.db.storage.paths, {"beta/beta-doc/report.pdf"})

    def test_orphan_file_cleanup_failure_is_reported_and_retryable(self):
        self.db.rows["documents"] = [self.db.rows["documents"][1]]
        self.db.storage.paths.add("alpha/no-metadata/orphan.pdf")
        self.db.storage.fail = True
        with self.assertRaises(HTTPException) as caught:
            auth.delete_account("alpha")
        self.assertEqual(caught.exception.status_code, 503)
        self.assertIn("alpha/no-metadata/orphan.pdf", self.db.storage.paths)
        self.db.storage.fail = False
        auth.delete_account("alpha")
        self.assertEqual(self.db.storage.paths, {"beta/beta-doc/report.pdf"})

    def test_production_missing_qdrant_cannot_fall_back_to_local_store(self):
        with patch.object(config.settings, "is_production", True), patch.object(vector_store, "_get_chroma_store", return_value=self.store):
            with self.assertRaises(ValueError): original_get_vector_store()

    def test_deleted_document_queued_job_does_not_recreate_records(self):
        from app.ai import pipeline
        self.db.rows["documents"] = []
        with patch.object(pipeline, "supabase", self.db), patch.object(pipeline, "_run_pipeline", side_effect=AssertionError("deleted record must not be analyzed")):
            pipeline.ingest("alpha-doc", "alpha")
        self.assertEqual(self.db.rows["documents"], [])

    def test_reingestion_clears_old_events_and_chunks(self):
        from app.ai import pipeline
        self.db.rows["health_events"] = [{"document_id":"alpha-doc", "user_id":"alpha"}, {"document_id":"beta-doc", "user_id":"beta"}]
        def rebuild(document_id, user_id):
            self.assertNotIn("alpha-1", self.store._collection.get()["ids"])
            self.assertEqual(self.db.rows["health_events"], [{"document_id":"beta-doc", "user_id":"beta"}])
        with patch.object(pipeline, "supabase", self.db), patch.object(pipeline, "_run_pipeline", side_effect=rebuild):
            pipeline.ingest("alpha-doc", "alpha")
        self.assertEqual(self.db.rows["documents"][0]["status"], "complete")

    def test_same_user_operations_wait_for_active_ingestion(self):
        from app.services.document_lifecycle import user_operation
        entered, finished = threading.Event(), threading.Event()
        def cleanup():
            entered.set()
            with user_operation("alpha"): finished.set()
        with user_operation("alpha"):
            thread = threading.Thread(target=cleanup)
            thread.start()
            self.assertTrue(entered.wait(1))
            self.assertFalse(finished.wait(0.05))
        thread.join(1)
        self.assertTrue(finished.is_set())

    def test_upload_waiting_on_deletion_cannot_recreate_records(self):
        from app.services import document_lifecycle as lifecycle
        with lifecycle.account_reset("alpha"):
            with self.assertRaises(HTTPException) as caught:
                with lifecycle.upload_operation("alpha"):
                    self.fail("Upload must not be admitted during record cleanup")
            self.assertEqual(caught.exception.status_code, 409)
        with lifecycle.upload_operation("alpha"):
            pass  # A deliberate new import after cleanup is allowed.

    def test_failed_explanation_stream_does_not_cache_partial_output(self):
        self.db.rows["documents"][0].update(status="complete", filename="synthetic.pdf", ocr_text="Synthetic lab record", mime_type="application/pdf")
        self.db.rows["analysis_results"] = [{"id":"analysis", "document_id":"alpha-doc", "user_id":"alpha", "explainer_text":None}]
        async def failure(**_):
            yield "Partial explanation"
            raise RuntimeError("synthetic provider failed with sensitive text")
        class Request:
            async def is_disconnected(self): return False
        async def consume():
            response = await documents.explain_document("alpha-doc", Request(), "alpha")
            return "".join([item async for item in response.body_iterator])
        with patch("app.ai.gemini_client.stream_completion", failure):
            output = asyncio.run(consume())
        self.assertIn("Explanation is unavailable", output)
        self.assertNotIn("sensitive text", output)
        self.assertIsNone(self.db.rows["analysis_results"][0]["explainer_text"])

    def test_upload_admitted_before_reset_is_rejected_after_waiting(self):
        from app.services import document_lifecycle as lifecycle
        captured, release = threading.Event(), threading.Event()
        errors = []
        real_operation = lifecycle.user_operation
        from contextlib import contextmanager
        @contextmanager
        def delayed_operation(owner):
            captured.set()
            release.wait(1)
            with real_operation(owner): yield
        def upload():
            try:
                with lifecycle.upload_operation("alpha"):
                    errors.append("unexpected upload")
            except HTTPException as error:
                errors.append(error.status_code)
        with patch.object(lifecycle, "user_operation", delayed_operation):
            thread = threading.Thread(target=upload)
            thread.start()
            self.assertTrue(captured.wait(1))
        with lifecycle.account_reset("alpha"):
            pass
        release.set()
        thread.join(1)
        self.assertEqual(errors, [409])

    def test_qdrant_deletion_is_scoped_to_owner_and_document(self):
        from qdrant_client import QdrantClient
        from qdrant_client.models import VectorParams, Distance
        from llama_index.vector_stores.qdrant import QdrantVectorStore
        import uuid
        client = QdrantClient(location=":memory:")
        client.create_collection(vector_store.COLLECTION_NAME, vectors_config=VectorParams(size=8, distance=Distance.COSINE))
        store = QdrantVectorStore(client=client, collection_name=vector_store.COLLECTION_NAME)
        with patch.object(vector_store, "get_vector_store", return_value=store):
            for owner, doc in [("alpha", "shared"), ("beta", "shared"), ("alpha", "keep")]:
                node = TextNode(id_=str(uuid.uuid4()), text="synthetic", metadata={})
                vector_store.index_nodes([node], [[0.5]*8], owner, doc)
            vector_store.delete_document_vectors("shared", "alpha")
            records, _ = client.scroll(vector_store.COLLECTION_NAME, with_payload=True)
            self.assertCountEqual([(r.payload["user_id"], r.payload["document_id"]) for r in records], [("beta", "shared"), ("alpha", "keep")])
            for owner in ["alpha", "beta"]:
                store.add([TextNode(id_=str(uuid.uuid4()), text="synthetic old payload", metadata={"user_id":owner, "document_id":"legacy-doc"}, embedding=[0.5]*8)])
            vector_store.delete_document_vectors("legacy-doc", "alpha")
            records, _ = client.scroll(vector_store.COLLECTION_NAME, with_payload=True)
            self.assertFalse(any(r.payload["user_id"] == "alpha" and r.payload["document_id"] == "None" for r in records))
            vector_store.delete_user_vectors("alpha")
            records, _ = client.scroll(vector_store.COLLECTION_NAME, with_payload=True)
            self.assertEqual([r.payload["user_id"] for r in records], ["beta", "beta"])
        client.close()


if __name__ == "__main__": unittest.main()

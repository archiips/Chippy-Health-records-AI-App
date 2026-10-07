"""Single-process MVP lifecycle coordination; use a durable queue before multi-worker deployment."""
from contextlib import contextmanager
from threading import Lock, RLock

from fastapi import HTTPException

from app.ai.vector_store import delete_document_vectors

_registry_lock = Lock()
_operations: dict[str, tuple[RLock, int]] = {}
_upload_epochs: dict[str, object] = {}
_resets_inflight: dict[str, int] = {}


@contextmanager
def account_reset(user_id: str):
    with _registry_lock:
        _upload_epochs[user_id] = object()
        _resets_inflight[user_id] = _resets_inflight.get(user_id, 0) + 1
    try:
        with user_operation(user_id):
            yield
    finally:
        with _registry_lock:
            count = _resets_inflight[user_id]
            if count == 1:
                del _resets_inflight[user_id]
            else:
                _resets_inflight[user_id] = count - 1


@contextmanager
def upload_operation(user_id: str):
    with _registry_lock:
        epoch = _upload_epochs.get(user_id)
        if _resets_inflight.get(user_id):
            raise HTTPException(status_code=409, detail="Record cleanup is in progress. Import again when it finishes.")
    with user_operation(user_id):
        with _registry_lock:
            if _resets_inflight.get(user_id) or _upload_epochs.get(user_id) is not epoch:
                raise HTTPException(status_code=409, detail="Record cleanup invalidated this import. Please import again.")
        yield


def delete_owned_storage(database, user_id: str) -> None:
    """Remove orphaned uploads too; paginate before deletion so offsets stay stable."""
    if not user_id or "/" in user_id or user_id in {".", ".."}:
        raise ValueError("Invalid storage owner")
    bucket = database.storage.from_("medical-documents")

    def remove_folder(path: str) -> None:
        offset = 0
        entries = []
        while True:
            page = bucket.list(path, {"limit": 100, "offset": offset, "sortBy": {"column": "name", "order": "asc"}})
            entries.extend(page)
            if len(page) < 100:
                break
            offset += len(page)
        files = []
        for entry in entries:
            name = entry["name"]
            if not name or "/" in name or name in {".", ".."}:
                raise ValueError("Invalid storage entry")
            target = f"{path}/{name}"
            if entry.get("id") is None:
                remove_folder(target)
            else:
                files.append(target)
        for start in range(0, len(files), 100):
            bucket.remove(files[start:start + 100])

    remove_folder(user_id)


@contextmanager
def user_operation(user_id: str):
    # Count waiters as well as active operations so a lock cannot be replaced
    # while another thread is waiting for it.
    with _registry_lock:
        lock, count = _operations.get(user_id, (RLock(), 0))
        _operations[user_id] = (lock, count + 1)
    try:
        with lock:
            yield
    finally:
        with _registry_lock:
            lock, count = _operations[user_id]
            if count == 1:
                del _operations[user_id]
            else:
                _operations[user_id] = (lock, count - 1)


def delete_owned_document(database, document_id: str, user_id: str) -> None:
    """Caller holds user_operation; metadata survives unsuccessful cleanup."""
    result = database.table("documents").select("id, file_path").eq("id", document_id).eq("user_id", user_id).execute()
    if not result.data:
        raise HTTPException(status_code=404, detail="Document not found")
    row = result.data[0]
    path = row["file_path"]
    if not isinstance(path, str) or not path.startswith(f"{user_id}/{document_id}/") or any(part in {".", "..", ""} for part in path.split("/")):
        raise HTTPException(status_code=503, detail="Stored file ownership could not be verified. Cleanup was stopped.")
    try:
        delete_document_vectors(document_id, user_id)
        database.storage.from_("medical-documents").remove([path])
    except Exception:
        raise HTTPException(status_code=503, detail="Document cleanup could not finish. Please retry.") from None
    database.table("documents").delete().eq("id", document_id).eq("user_id", user_id).execute()

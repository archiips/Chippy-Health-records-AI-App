from datetime import date, datetime
from typing import Any
from uuid import UUID

from pydantic import BaseModel, EmailStr


# ─── Auth ────────────────────────────────────────────────────────────────────

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class RefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: str
    email: str = ""


# ─── Documents ───────────────────────────────────────────────────────────────

class DocumentResponse(BaseModel):
    id: UUID
    filename: str
    document_type: str
    status: str
    file_size: int | None = None
    mime_type: str | None = None
    created_at: datetime
    analysis_result: dict[str, Any] | None = None


class UploadResponse(BaseModel):
    document_id: str
    status: str = "processing"


class SignedUrlResponse(BaseModel):
    url: str
    expires_in: int = 3600


class DocumentStatusResponse(BaseModel):
    document_id: str
    status: str                       # processing | complete | failed
    document_type: str | None = None
    error_message: str | None = None


# ─── Timeline ─────────────────────────────────────────────────────────────────

class HealthEventResponse(BaseModel):
    id: str
    document_id: str
    title: str
    category: str
    event_date: date | None = None
    summary: str | None = None
    created_at: datetime

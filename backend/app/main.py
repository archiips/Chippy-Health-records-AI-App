from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Ping Qdrant on startup to reset its inactivity timer (free tier suspends after 1 week)
    if settings.is_production and settings.qdrant_url:
        try:
            from qdrant_client import QdrantClient
            client = QdrantClient(url=settings.qdrant_url, api_key=settings.qdrant_api_key)
            client.get_collections()
        except Exception as e:
            # Non-fatal — log and continue; Qdrant will re-connect on first request
            print(f"[startup] Qdrant ping failed: {e}")

    yield
    # Shutdown cleanup goes here if needed


app = FastAPI(
    title="Chippy API",
    description="Backend for Chippy — health records AI app",
    version="0.1.0",
    lifespan=lifespan,
    # Disable docs in production if desired:
    # docs_url=None if settings.is_production else "/docs",
)

app.add_middleware(
    CORSMiddleware,
    # Tighten to specific origins before App Store release
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


from app.api import auth, chat, documents, timeline
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(documents.router, prefix="/documents", tags=["documents"])
app.include_router(chat.router)
app.include_router(timeline.router)


@app.get("/health", tags=["health"])
async def health_check():
    return {"status": "ok", "env": settings.env}

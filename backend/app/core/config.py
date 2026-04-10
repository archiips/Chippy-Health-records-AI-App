from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Gemini — used for embeddings + document extraction
    google_api_key: str

    # Supabase
    supabase_url: str
    supabase_service_key: str   # service_role — bypasses RLS (server-side only)
    supabase_anon_key: str      # anon/public — used for client-facing auth calls

    # Qdrant Cloud (omit in dev — Chroma is used automatically when ENV=development)
    qdrant_url: str = ""
    qdrant_api_key: str = ""

    # JWT (FastAPI issues its own tokens; Supabase Auth manages user storage)
    jwt_secret_key: str
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 15
    jwt_refresh_token_expire_days: int = 30

    # "development" → local Chroma  |  "production" → Qdrant Cloud
    env: str = "development"

    @property
    def is_production(self) -> bool:
        return self.env == "production"


settings = Settings()

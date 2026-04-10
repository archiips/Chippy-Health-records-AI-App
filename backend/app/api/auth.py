from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status

from app.core.auth import create_access_token, create_refresh_token, decode_token, get_current_user
from app.core.supabase_client import supabase, supabase_auth
from app.models.schemas import LoginRequest, RefreshRequest, RegisterRequest, TokenResponse

CurrentUser = Annotated[str, Depends(get_current_user)]

router = APIRouter()


@router.post("/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED)
def register(body: RegisterRequest):
    try:
        result = supabase_auth.auth.sign_up({"email": body.email, "password": body.password})
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

    if not result.user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Registration failed — email may already be in use",
        )

    user_id = str(result.user.id)
    return TokenResponse(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
        user_id=user_id,
        email=result.user.email or "",
    )


@router.post("/login", response_model=TokenResponse)
def login(body: LoginRequest):
    try:
        result = supabase_auth.auth.sign_in_with_password({"email": body.email, "password": body.password})
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))

    if not result.user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    user_id = str(result.user.id)
    return TokenResponse(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
        user_id=user_id,
        email=result.user.email or "",
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh(body: RefreshRequest):
    user_id = decode_token(body.refresh_token, expected_type="refresh")
    return TokenResponse(
        access_token=create_access_token(user_id),
        refresh_token=create_refresh_token(user_id),
        user_id=user_id,
    )


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout():
    # Tokens are stateless JWTs — client deletes them from Keychain.
    return


@router.delete("/account", status_code=status.HTTP_204_NO_CONTENT)
def delete_account(user_id: CurrentUser):
    """Delete all user data. Auth account remains in Supabase (user can re-register)."""
    # Delete storage files first
    try:
        files = supabase.storage.from_("medical-documents").list(path=user_id)
        if files:
            for folder in files:
                folder_path = f"{user_id}/{folder['name']}"
                contents = supabase.storage.from_("medical-documents").list(path=folder_path)
                if contents:
                    paths = [f"{folder_path}/{f['name']}" for f in contents]
                    supabase.storage.from_("medical-documents").remove(paths)
    except Exception as e:
        print(f"[delete_account] Storage cleanup failed (continuing): {e}")

    # Delete DB rows — cascades to analysis_results, health_events
    supabase.table("documents").delete().eq("user_id", user_id).execute()
    supabase.table("chat_messages").delete().eq("user_id", user_id).execute()

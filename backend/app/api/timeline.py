"""
Timeline API — Sprint 4.

GET /timeline         — all health_events for user, optional category + date filters
GET /timeline/{id}    — single event
"""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.auth import get_current_user
from app.core.supabase_client import supabase
from app.models.schemas import HealthEventResponse

router = APIRouter(prefix="/timeline", tags=["timeline"])

CurrentUser = Annotated[str, Depends(get_current_user)]


@router.get("", response_model=list[HealthEventResponse])
def get_timeline(
    user_id: CurrentUser,
    category: str | None = Query(None),
    from_date: date | None = Query(None, alias="from"),
    to_date: date | None = Query(None, alias="to"),
):
    query = (
        supabase.table("health_events")
        .select("*")
        .eq("user_id", user_id)
    )
    if category:
        query = query.eq("category", category)
    if from_date:
        query = query.gte("event_date", from_date.isoformat())
    if to_date:
        query = query.lte("event_date", to_date.isoformat())

    result = query.order("event_date", desc=True).execute()
    return result.data or []


@router.get("/{event_id}", response_model=HealthEventResponse)
def get_event(event_id: str, user_id: CurrentUser):
    result = (
        supabase.table("health_events")
        .select("*")
        .eq("id", event_id)
        .eq("user_id", user_id)
        .single()
        .execute()
    )
    if not result.data:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Event not found")
    return result.data

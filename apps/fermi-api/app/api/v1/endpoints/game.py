"""Game endpoints."""

from typing import Annotated

from fastapi import APIRouter, Depends, Request
from fermi_db.models.user import User
from google.cloud.firestore_v1.async_client import AsyncClient
from opentelemetry import trace

import app.logging.attributes as api_attrs
from app.api.v1.auth_deps import get_current_user
from app.api.v1.dependencies import (
    get_firestore_client,
    get_game_service,
    verify_scheduler_secret,
)
from app.api.v1.rate_limit import (
    GAME_CLEANUP_RATE_LIMIT,
    limiter,
)
from app.schemas.endpoints import (
    GameConfigResponse,
    GetPlayerStatsResponse,
)
from app.services.game.service import GameService

router = APIRouter()


@router.post('/get_player_stats', response_model=GetPlayerStatsResponse)
async def get_player_stats(
    request: Request,
    current_user: Annotated[User, Depends(get_current_user)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> GetPlayerStatsResponse:
    """Get the current user's stats."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_player_stats.__qualname__)
    span.set_attribute(api_attrs.FIREBASE_UID, current_user.firebase_uid)
    return await game_service.get_player_stats(
        player_id=current_user.firebase_uid,
        request=request,
    )


@router.get('/config', response_model=GameConfigResponse)
async def get_game_config(
    request: Request,
    _: Annotated[User, Depends(get_current_user)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> GameConfigResponse:
    """Get the static game config.

    This endpoint returns configuration that never changes per user
    (categories, difficulties, ranks). It should be called once at
    startup and cached.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_game_config.__qualname__)
    return await game_service.get_game_config(request)


@router.delete('/cleanup')
@limiter.limit(GAME_CLEANUP_RATE_LIMIT)
async def cleanup_finished_games(
    request: Request,
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    game_service: Annotated[GameService, Depends(get_game_service)],
    _: Annotated[None, Depends(verify_scheduler_secret)],
    max_games: int = 100,
) -> dict[str, int]:
    """Delete finished/aborted games. Intended for scheduled cleanup jobs.

    No authentication required. Rate limited to prevent abuse.

    Args:
        request: FastAPI request (for rate limiter).
        firestore_client: Firestore client dependency.
        game_service: Game service dependency.
        max_games: Maximum number of games to delete (default 100).

    Returns:
        Dictionary with 'deleted' count.

    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, cleanup_finished_games.__qualname__)
    span.set_attribute('max_games', max_games)
    deleted = await game_service.cleanup_finished_games(
        firestore_client=firestore_client,
        max_games=max_games,
    )
    return {'deleted': deleted}

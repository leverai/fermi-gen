"""Game endpoints."""

from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, Request
from fastapi.responses import HTMLResponse
from fermi_db.models.user import User
from google.cloud.firestore_v1.async_client import AsyncClient

from app.api.v1.auth_deps import get_current_user
from app.api.v1.dependencies import get_firestore_client, get_game_service
from app.schemas.endpoints import (
    GameAnswerRequest,
    GameConfigResponse,
    GameCreateRequest,
    GameJoinRandomRequest,
    GameRemovePlayerRequest,
    GetPlayerStatsRequest,
    GetPlayerStatsResponse,
    IdModel,
)
from app.services.game.service import GameService

router = APIRouter()


@router.post('/create', response_model=IdModel)
async def create_game(
    request: Request,
    payload: GameCreateRequest,
    background_tasks: BackgroundTasks,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> IdModel:
    """Create a new game."""
    return await game_service.create_game(
        request=request,
        payload=payload,
        background_tasks=background_tasks,
        current_user=current_user,
        firestore_client=firestore_client,
    )


@router.post('/start', response_model=IdModel)
async def start_game(
    payload: IdModel,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> IdModel:
    """Start a game. Only the host can start the game."""
    return await game_service.start_game(
        payload=payload,
        current_user=current_user,
        firestore_client=firestore_client,
    )


@router.post('/next_question', response_model=IdModel)
async def next_question(
    payload: IdModel,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> IdModel:
    """Move to the next question. Only the host can trigger this."""
    return await game_service.next_question(
        payload=payload,
        current_user=current_user,
        firestore_client=firestore_client,
    )


@router.post('/end', response_model=IdModel)
async def end_game(
    payload: IdModel,
    background_tasks: BackgroundTasks,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> IdModel:
    """End a game. Only the host can end the game."""
    return await game_service.end_game(
        payload=payload,
        background_tasks=background_tasks,
        current_user=current_user,
        firestore_client=firestore_client,
    )


@router.post('/join_random', response_model=IdModel)
async def join_random_game(
    request: Request,
    payload: GameJoinRandomRequest,
    background_tasks: BackgroundTasks,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> IdModel:
    """Join a random game."""
    return await game_service.join_or_create_game(
        request=request,
        payload=payload,
        background_tasks=background_tasks,
        current_user=current_user,
        firestore_client=firestore_client,
    )


@router.post('/join', response_model=IdModel)
async def join_game(
    payload: IdModel,
    background_tasks: BackgroundTasks,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> IdModel:
    """Join a game."""
    return await game_service.join_game(
        payload=payload,
        background_tasks=background_tasks,
        current_user=current_user,
        firestore_client=firestore_client,
    )


@router.post('/answer', response_model=IdModel)
async def answer_question(
    payload: GameAnswerRequest,
    background_tasks: BackgroundTasks,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> IdModel:
    """Submit an answer for the current question."""
    return await game_service.submit_answer(
        payload=payload,
        background_tasks=background_tasks,
        current_user=current_user,
        firestore_client=firestore_client,
    )


@router.post('/remove_player', response_model=IdModel)
async def remove_player(
    payload: GameRemovePlayerRequest,
    background_tasks: BackgroundTasks,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> IdModel:
    """Remove a player from a game."""
    return await game_service.remove_player(
        payload=payload,
        background_tasks=background_tasks,
        current_user=current_user,
        firestore_client=firestore_client,
    )


@router.post('/get_player_stats', response_model=GetPlayerStatsResponse)
async def get_player_stats(
    payload: GetPlayerStatsRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> GetPlayerStatsResponse:
    """Get a player's stats."""
    return await game_service.get_player_stats(
        payload=payload,
    )


@router.get('/config', response_model=GameConfigResponse)
async def get_game_config(
    request: Request,
    current_user: Annotated[User, Depends(get_current_user)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> GameConfigResponse:
    """Get the game config."""
    return await game_service.get_game_config(request)


@router.get('/invite/{game_id}', response_class=HTMLResponse)
async def invite_player(game_id: str) -> HTMLResponse:
    """Deep link trampoline for game invites."""
    # TODO: Make this configurable
    play_store_url = 'https://play.google.com/store/apps/details?id=com.fermi.app'
    app_store_url = 'https://apps.apple.com/app/idYOUR_APP_ID'  # TODO: Replace with actual App Store URL
    deep_link = f'guesstimate://invite/{game_id}'

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>Join Game</title>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
    </head>
    <body>
        <p>Opening game...</p>
        <script>
            var deepLink = "{deep_link}";
            var playStoreUrl = "{play_store_url}";
            var appStoreUrl = "{app_store_url}";

            // Try to open the app
            window.location.href = deepLink;

            // Fallback to Store after a timeout
            setTimeout(function() {{
                var userAgent = navigator.userAgent || navigator.vendor || window.opera;
                if (/iPad|iPhone|iPod/.test(userAgent) && !window.MSStream) {{
                    window.location.href = appStoreUrl;
                }} else {{
                    window.location.href = playStoreUrl;
                }}
            }}, 2000);
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content, status_code=200)

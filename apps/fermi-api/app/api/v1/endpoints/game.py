"""Game endpoints."""

from typing import Annotated

from fastapi import APIRouter, BackgroundTasks, Depends, Request
from fastapi.responses import HTMLResponse
from fermi_db.models.user import User
from google.cloud.firestore_v1.async_client import AsyncClient
from opentelemetry import trace

import app.logging.attributes as api_attrs
from app.api.v1.auth_deps import get_current_user
from app.api.v1.dependencies import get_firestore_client, get_game_service
from app.api.v1.rate_limit import GAME_CREATE_RATE_LIMIT, limiter
from app.schemas.endpoints import (
    AddBotsRequest,
    GameAnswerRequest,
    GameConfigResponse,
    GameCreateRequest,
    GameRemovePlayerRequest,
    GetPlayerStatsRequest,
    GetPlayerStatsResponse,
    IdModel,
)
from app.services.game.service import GameService

router = APIRouter()


@router.post('/create', response_model=IdModel)
@limiter.limit(GAME_CREATE_RATE_LIMIT)
async def create_game(
    request: Request,
    payload: GameCreateRequest,
    background_tasks: BackgroundTasks,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> IdModel:
    """Create a new game."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, create_game.__qualname__)
    span.set_attribute(
        api_attrs.QUERY_PARAMS,
        payload.model_dump_json(exclude_none=True),
    )
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
    background_tasks: BackgroundTasks,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> IdModel:
    """Start a game. Only the host can start the game."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, start_game.__qualname__)
    span.set_attribute(api_attrs.GAME_ID, payload.resource_id)
    return await game_service.start_game(
        payload=payload,
        background_tasks=background_tasks,
        current_user=current_user,
        firestore_client=firestore_client,
    )


@router.post('/next_question', response_model=IdModel)
async def next_question(
    payload: IdModel,
    background_tasks: BackgroundTasks,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> IdModel:
    """Move to the next question. Only the host can trigger this."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, next_question.__qualname__)
    span.set_attribute(api_attrs.GAME_ID, payload.resource_id)
    return await game_service.next_question(
        payload=payload,
        background_tasks=background_tasks,
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
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, end_game.__qualname__)
    span.set_attribute(api_attrs.GAME_ID, payload.resource_id)
    return await game_service.end_game(
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
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, join_game.__qualname__)
    span.set_attribute(api_attrs.GAME_ID, payload.resource_id)
    return await game_service.join_game(
        payload=payload,
        background_tasks=background_tasks,
        current_user=current_user,
        firestore_client=firestore_client,
    )


@router.post('/add_bots', response_model=IdModel)
async def add_bots(
    request: Request,
    payload: AddBotsRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> IdModel:
    """Add bots to a game. Only the host can add bots."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, add_bots.__qualname__)
    span.set_attribute(api_attrs.GAME_ID, payload.resource_id)
    span.set_attribute(api_attrs.QUERY_PARAMS, payload.model_dump_json())
    return await game_service.add_bots(
        request=request,
        game_id=payload.resource_id,
        bot_ids=payload.bot_ids,
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
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, answer_question.__qualname__)
    span.set_attribute(api_attrs.GAME_ID, payload.resource_id)
    span.set_attribute(api_attrs.QUERY_PARAMS, payload.model_dump_json())
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
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, remove_player.__qualname__)
    span.set_attribute(api_attrs.GAME_ID, payload.resource_id)
    span.set_attribute(api_attrs.QUERY_PARAMS, payload.model_dump_json())
    return await game_service.remove_player(
        payload=payload,
        background_tasks=background_tasks,
        current_user=current_user,
        firestore_client=firestore_client,
    )


@router.post('/get_player_stats', response_model=GetPlayerStatsResponse)
async def get_player_stats(
    request: Request,
    payload: GetPlayerStatsRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> GetPlayerStatsResponse:
    """Get a player's stats."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_player_stats.__qualname__)
    span.set_attribute(api_attrs.QUERY_PARAMS, payload.model_dump_json())
    return await game_service.get_player_stats(
        payload=payload,
        request=request,
    )


@router.get('/config', response_model=GameConfigResponse)
async def get_game_config(
    request: Request,
    current_user: Annotated[User, Depends(get_current_user)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> GameConfigResponse:
    """Get the game config."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_game_config.__qualname__)
    return await game_service.get_game_config(request)


@router.get('/invite/{game_id}', response_class=HTMLResponse)
async def invite_player(game_id: str) -> HTMLResponse:
    """Deep link trampoline for game invites."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, invite_player.__qualname__)
    span.set_attribute(api_attrs.GAME_ID, game_id)
    # TODO: Make this configurable
    play_store_url = (
        'https://play.google.com/store/apps/details?id=tech.leverai.guesstimate'
    )
    app_store_url = 'https://apps.apple.com/app/id6756033242'
    app_package = 'tech.leverai.guesstimate'
    deep_link = f'guesstimate://invite/{game_id}'

    # Android intent URI - more reliable than custom scheme for Chrome/WebView
    # Format: intent://HOST/PATH#Intent;scheme=SCHEME;package=PACKAGE;end
    intent_uri = (
        f'intent://invite/{game_id}#Intent;'
        f'scheme=guesstimate;'
        f'package={app_package};'
        f'S.browser_fallback_url={play_store_url};'
        'end'
    )

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
            var intentUri = "{intent_uri}";
            var playStoreUrl = "{play_store_url}";
            var appStoreUrl = "{app_store_url}";

            var userAgent = navigator.userAgent || navigator.vendor || window.opera;
            var isIOS = /iPad|iPhone|iPod/.test(userAgent) && !window.MSStream;
            var isAndroid = /android/i.test(userAgent);

            if (isIOS) {{
                // iOS: Try custom scheme, fallback to App Store
                window.location.href = deepLink;
                setTimeout(function() {{
                    window.location.href = appStoreUrl;
                }}, 2000);
            }} else if (isAndroid) {{
                // Android: Use intent URI for reliable app launch
                // Intent URI handles fallback automatically via S.browser_fallback_url
                window.location.href = intentUri;
            }} else {{
                // Other platforms: Try custom scheme, fallback to Play Store
                window.location.href = deepLink;
                setTimeout(function() {{
                    window.location.href = playStoreUrl;
                }}, 2000);
            }}
        </script>
    </body>
    </html>
    """
    return HTMLResponse(content=html_content, status_code=200)

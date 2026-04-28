"""DeathMatch endpoints."""

from typing import Annotated

from fastapi import APIRouter, Depends, Request
from fermi_db.models.user import User
from google.cloud.firestore_v1.async_client import AsyncClient
from opentelemetry import trace

import app.logging.attributes as api_attrs
from app.api.v1.auth_deps import get_current_user
from app.api.v1.dependencies import get_deathmatch_service, get_firestore_client
from app.api.v1.rate_limit import GAME_CREATE_RATE_LIMIT, limiter
from app.schemas.deathmatch import (
    DMAnswerRequest,
    DMAnswerResponse,
    DMLeaveResponse,
    DMMatchStatusResponse,
    DMQueueResponse,
    DMResultResponse,
)
from app.services.deathmatch.service import DeathMatchService

router = APIRouter()


@router.post('/queue', response_model=DMQueueResponse)
@limiter.limit(GAME_CREATE_RATE_LIMIT)
async def queue_deathmatch(
    request: Request,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    dm_service: Annotated[DeathMatchService, Depends(get_deathmatch_service)],
) -> DMQueueResponse:
    """Enter the DeathMatch matchmaking queue.

    If an opponent is available, a match is created immediately.
    Otherwise, the player waits in the queue.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, queue_deathmatch.__qualname__)
    span.set_attribute(api_attrs.DM_PLAYER_ID, current_user.firebase_uid)
    return await dm_service.queue(
        current_user_firebase_uid=current_user.firebase_uid,
        current_user_name=current_user.display_name,
        current_user_picture=current_user.picture,
        firestore_client=firestore_client,
    )


@router.get('/match/{match_id}', response_model=DMMatchStatusResponse)
async def get_match_status(
    match_id: str,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    dm_service: Annotated[DeathMatchService, Depends(get_deathmatch_service)],
) -> DMMatchStatusResponse:
    """Get match status. If still waiting, attempts bot match."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_match_status.__qualname__)
    span.set_attribute(api_attrs.DM_MATCH_ID, match_id)
    return await dm_service.check_and_match(
        match_id=match_id,
        current_user_firebase_uid=current_user.firebase_uid,
        firestore_client=firestore_client,
    )


@router.post('/answer', response_model=DMAnswerResponse | DMResultResponse)
@limiter.limit(GAME_CREATE_RATE_LIMIT)
async def submit_answer(
    request: Request,
    payload: DMAnswerRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    dm_service: Annotated[DeathMatchService, Depends(get_deathmatch_service)],
) -> DMAnswerResponse | DMResultResponse:
    """Submit an answer for the current DeathMatch question."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, submit_answer.__qualname__)
    span.set_attribute(api_attrs.DM_MATCH_ID, payload.match_id)
    return await dm_service.submit_answer(
        match_id=payload.match_id,
        current_user_firebase_uid=current_user.firebase_uid,
        answer=payload.answer,
        firestore_client=firestore_client,
    )


@router.get('/result/{match_id}', response_model=DMResultResponse)
async def get_result(
    match_id: str,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    dm_service: Annotated[DeathMatchService, Depends(get_deathmatch_service)],
) -> DMResultResponse:
    """Get the result of a completed DeathMatch."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_result.__qualname__)
    span.set_attribute(api_attrs.DM_MATCH_ID, match_id)
    return await dm_service.get_result(
        match_id=match_id,
        current_user_firebase_uid=current_user.firebase_uid,
        firestore_client=firestore_client,
    )


@router.post('/leave/{match_id}', response_model=DMLeaveResponse)
async def leave_match(
    match_id: str,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    dm_service: Annotated[DeathMatchService, Depends(get_deathmatch_service)],
) -> DMLeaveResponse:
    """Leave the queue or forfeit a match."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, leave_match.__qualname__)
    span.set_attribute(api_attrs.DM_MATCH_ID, match_id)
    return await dm_service.leave(
        match_id=match_id,
        current_user_firebase_uid=current_user.firebase_uid,
        firestore_client=firestore_client,
    )

"""Question endpoints."""

from typing import Annotated

from fastapi import APIRouter, Depends
from fermi_db.models.user import User
from opentelemetry import trace

import app.logging.attributes as api_attrs
from app.api.v1.auth_deps import get_current_user
from app.api.v1.dependencies import get_game_service
from app.api.v1.rate_limit import QUESTION_VOTE_RATE_LIMIT, limiter
from app.schemas.endpoints import IdModel, VoteVerdictResponse
from app.services.game.service import GameService

router = APIRouter()


@router.post('/upvote', response_model=VoteVerdictResponse)
@limiter.limit(QUESTION_VOTE_RATE_LIMIT)
async def upvote_question(
    vote_request: IdModel,
    current_user: Annotated[User, Depends(get_current_user)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> VoteVerdictResponse:
    """Upvote a question."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, upvote_question.__qualname__)
    span.set_attribute(api_attrs.QUESTION_UID, vote_request.resource_id)
    verdict = await game_service.vote(
        question_uid=vote_request.resource_id,
        user_firebase_uid=current_user.firebase_uid,
        verdict=1,
    )
    return VoteVerdictResponse(resource_id=vote_request.resource_id, verdict=verdict)


@router.post('/downvote', response_model=VoteVerdictResponse)
@limiter.limit(QUESTION_VOTE_RATE_LIMIT)
async def downvote_question(
    vote_request: IdModel,
    current_user: Annotated[User, Depends(get_current_user)],
    game_service: Annotated[GameService, Depends(get_game_service)],
) -> VoteVerdictResponse:
    """Downvote a question."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, downvote_question.__qualname__)
    span.set_attribute(api_attrs.QUESTION_UID, vote_request.resource_id)
    verdict = await game_service.vote(
        question_uid=vote_request.resource_id,
        user_firebase_uid=current_user.firebase_uid,
        verdict=-1,
    )
    return VoteVerdictResponse(resource_id=vote_request.resource_id, verdict=verdict)

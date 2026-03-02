"""Precision Rush endpoints."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request
from fermi_db.models.user import User
from opentelemetry import trace

import app.logging.attributes as api_attrs
from app.api.v1.auth_deps import get_authenticated_user, get_current_user
from app.api.v1.authenticated_user import AuthenticatedUser
from app.api.v1.dependencies import get_precision_rush_service
from app.api.v1.rate_limit import (
    GAME_CREATE_RATE_LIMIT,
    LEADERBOARD_RATE_LIMIT,
    limiter,
)
from app.schemas.precision_rush import (
    PRAnswerRequest,
    PRAnswerResponse,
    PRLeaderboardResponse,
    PRQuestionResponse,
    PRStatsResponse,
)
from app.schemas.survival import CreateOrResumeRequest, LeaderboardPeriod
from app.services.precision_rush import PrecisionRushService

router = APIRouter()


@router.post('/create_or_resume', response_model=PRQuestionResponse)
@limiter.limit(GAME_CREATE_RATE_LIMIT)
async def start_pr_run(
    request: Request,
    payload: CreateOrResumeRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    auth_user: Annotated[AuthenticatedUser, Depends(get_authenticated_user)],
    pr_service: Annotated[PrecisionRushService, Depends(get_precision_rush_service)],
    *,
    with_ad: bool = Query(
        default=False,
        description='Allow access after watching a rewarded ad (bypasses run limit)',
    ),
) -> PRQuestionResponse:
    """Start a new Precision Rush run or resume an existing one.

    Returns the next question with a 40-second timer.
    Free users are limited to 1 run per day unless with_ad=True.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, start_pr_run.__qualname__)
    span.set_attribute(
        api_attrs.QUERY_PARAMS,
        f'run_id={payload.run_id}&with_ad={with_ad}',
    )

    return await pr_service.create_or_resume_run(
        user_firebase_uid=current_user.firebase_uid,
        run_id=payload.run_id,
        is_pro=auth_user.is_pro or with_ad,
    )


@router.post('/answer', response_model=PRAnswerResponse)
@limiter.limit(GAME_CREATE_RATE_LIMIT)
async def submit_pr_answer(
    request: Request,
    payload: PRAnswerRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    pr_service: Annotated[PrecisionRushService, Depends(get_precision_rush_service)],
) -> PRAnswerResponse:
    """Submit an answer for the current PR question.

    Returns accuracy score, TAS, and percentile.
    After 6th question, includes run summary.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, submit_pr_answer.__qualname__)
    span.set_attribute(api_attrs.QUERY_PARAMS, f'run_id={payload.run_id}')

    return await pr_service.submit_answer(
        user_firebase_uid=current_user.firebase_uid,
        run_id=payload.run_id,
        answer=payload.answer,
    )


@router.get('/stats', response_model=PRStatsResponse)
@limiter.limit(GAME_CREATE_RATE_LIMIT)
async def get_pr_stats(
    request: Request,
    current_user: Annotated[User, Depends(get_current_user)],
    pr_service: Annotated[PrecisionRushService, Depends(get_precision_rush_service)],
) -> PRStatsResponse:
    """Get user's Precision Rush statistics."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_pr_stats.__qualname__)

    return await pr_service.get_stats(
        user_firebase_uid=current_user.firebase_uid,
    )


@router.get('/leaderboard', response_model=PRLeaderboardResponse)
@limiter.limit(LEADERBOARD_RATE_LIMIT)
async def get_pr_leaderboard(
    request: Request,
    current_user: Annotated[User, Depends(get_current_user)],
    pr_service: Annotated[PrecisionRushService, Depends(get_precision_rush_service)],
    page: int = Query(1, ge=1, description='Page number (1-indexed)'),
    page_size: int = Query(25, ge=1, le=100, description='Items per page'),
    period: LeaderboardPeriod = Query(  # noqa: B008
        LeaderboardPeriod.weekly,
        description=(
            'Time period filter: weekly, monthly, last_week, last_month, all_time'
        ),
    ),
) -> PRLeaderboardResponse:
    """Get global Precision Rush leaderboard.

    Returns paginated list of players sorted by best TAS (descending).
    Includes current user's rank regardless of their position in the page.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_pr_leaderboard.__qualname__)
    span.set_attribute(
        api_attrs.QUERY_PARAMS,
        f'page={page}&page_size={page_size}&period={period.value}',
    )

    return await pr_service.get_leaderboard(
        user_firebase_uid=current_user.firebase_uid,
        page=page,
        page_size=page_size,
        period=period,
        request=request,
    )

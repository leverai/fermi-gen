"""Survival Mode endpoints."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query, Request
from fermi_db.models.user import User
from opentelemetry import trace

import app.logging.attributes as api_attrs
from app.api.v1.auth_deps import get_authenticated_user, get_current_user
from app.api.v1.authenticated_user import AuthenticatedUser
from app.api.v1.dependencies import get_survival_service
from app.api.v1.rate_limit import (
    GAME_CREATE_RATE_LIMIT,
    LEADERBOARD_RATE_LIMIT,
    limiter,
)
from app.schemas.survival import (
    ContinueWithAdRequest,
    ContinueWithAdResponse,
    CreateOrResumeRequest,
    LeaderboardPeriod,
    LeaderboardResponse,
    StreakInfo,
    SurvivalAnswerRequest,
    SurvivalAnswerResponse,
    SurvivalQuestionResponse,
    SurvivalStatsResponse,
)
from app.services.survival import SurvivalService

router = APIRouter()


@router.post('/create_or_resume', response_model=SurvivalQuestionResponse)
@limiter.limit(GAME_CREATE_RATE_LIMIT)
async def start_survival_run(
    request: Request,
    payload: CreateOrResumeRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    auth_user: Annotated[AuthenticatedUser, Depends(get_authenticated_user)],
    survival_service: Annotated[SurvivalService, Depends(get_survival_service)],
    *,
    with_ad: bool = Query(
        default=False,
        description='Allow access after watching a rewarded ad (bypasses run limit)',
    ),
) -> SurvivalQuestionResponse:
    """Start a new survival run or resume an existing one.

    If the user has an active run, it resumes that run.
    Returns the next question with a 40-second timer.
    Free users are limited to 2 runs per day unless with_ad=True.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, start_survival_run.__qualname__)
    span.set_attribute(
        api_attrs.QUERY_PARAMS,
        f'run_id={payload.run_id}&with_ad={with_ad}',
    )

    response = await survival_service.create_or_resume_run(
        user_firebase_uid=current_user.firebase_uid,
        run_id=payload.run_id,
        is_pro=auth_user.is_pro or with_ad,  # Ad access bypasses limit
    )

    return response


@router.post('/answer', response_model=SurvivalAnswerResponse)
@limiter.limit(GAME_CREATE_RATE_LIMIT)
async def submit_survival_answer(
    request: Request,
    payload: SurvivalAnswerRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    survival_service: Annotated[SurvivalService, Depends(get_survival_service)],
) -> SurvivalAnswerResponse:
    """Submit an answer for the current survival question.

    Returns score, pass/fail status, and either the next question
    (if passed) or a run summary (if failed).
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, submit_survival_answer.__qualname__)
    span.set_attribute(api_attrs.QUERY_PARAMS, f'run_id={payload.run_id}')

    response = await survival_service.submit_answer(
        user_firebase_uid=current_user.firebase_uid,
        run_id=payload.run_id,
        answer=payload.answer,
    )

    return response


@router.post('/continue_with_ad', response_model=ContinueWithAdResponse)
@limiter.limit(GAME_CREATE_RATE_LIMIT)
async def continue_survival_with_ad(
    request: Request,
    payload: ContinueWithAdRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    survival_service: Annotated[SurvivalService, Depends(get_survival_service)],
) -> ContinueWithAdResponse:
    """Continue a failed survival run after watching a rewarded ad.

    Limited to 1 ad save per run.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, continue_survival_with_ad.__qualname__)
    span.set_attribute(api_attrs.QUERY_PARAMS, f'run_id={payload.run_id}')

    return await survival_service.continue_run_with_ad(
        user_firebase_uid=current_user.firebase_uid,
        run_id=payload.run_id,
    )


@router.get('/stats', response_model=SurvivalStatsResponse)
@limiter.limit(GAME_CREATE_RATE_LIMIT)
async def get_survival_stats(
    request: Request,
    current_user: Annotated[User, Depends(get_current_user)],
    survival_service: Annotated[SurvivalService, Depends(get_survival_service)],
) -> SurvivalStatsResponse:
    """Get user's survival mode statistics.

    Returns total runs, best streak, average streak, and total questions.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_survival_stats.__qualname__)

    return await survival_service.get_stats(
        user_firebase_uid=current_user.firebase_uid,
    )


@router.get('/streak', response_model=StreakInfo)
@limiter.limit(LEADERBOARD_RATE_LIMIT)
async def get_survival_streak(
    request: Request,
    current_user: Annotated[User, Depends(get_current_user)],
    survival_service: Annotated[SurvivalService, Depends(get_survival_service)],
) -> StreakInfo:
    """Get user's streak stats (current and best streak)."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_survival_streak.__qualname__)

    return await survival_service.get_streak_stats(
        user_firebase_uid=current_user.firebase_uid,
    )


@router.get('/leaderboard', response_model=LeaderboardResponse)
@limiter.limit(LEADERBOARD_RATE_LIMIT)
async def get_survival_leaderboard(
    request: Request,
    current_user: Annotated[User, Depends(get_current_user)],
    survival_service: Annotated[SurvivalService, Depends(get_survival_service)],
    page: int = Query(1, ge=1, description='Page number (1-indexed)'),
    page_size: int = Query(25, ge=1, le=100, description='Items per page'),
    period: LeaderboardPeriod = Query(  # noqa: B008
        LeaderboardPeriod.weekly,
        description=(
            'Time period filter: weekly, monthly, last_week, last_month, all_time'
        ),
    ),
) -> LeaderboardResponse:
    """Get global survival streak leaderboard.

    Returns paginated list of players sorted by best streak (descending).
    Includes current user's rank regardless of their position in the page.
    Supports time period filtering (weekly by default).
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_survival_leaderboard.__qualname__)
    span.set_attribute(
        api_attrs.QUERY_PARAMS,
        f'page={page}&page_size={page_size}&period={period.value}',
    )

    return await survival_service.get_leaderboard(
        user_firebase_uid=current_user.firebase_uid,
        page=page,
        page_size=page_size,
        period=period,
        request=request,
    )

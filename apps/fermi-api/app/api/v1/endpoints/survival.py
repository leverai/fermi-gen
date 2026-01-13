"""Survival Mode endpoints."""

from typing import Annotated

from fastapi import APIRouter, Depends
from fermi_db.models.user import User
from opentelemetry import trace

import app.logging.attributes as api_attrs
from app.api.v1.auth_deps import get_current_user
from app.api.v1.dependencies import get_survival_service
from app.schemas import (
    CreateOrResumeRequest,
    SurvivalAnswerRequest,
    SurvivalAnswerResponse,
    SurvivalQuestionResponse,
    SurvivalStatsResponse,
)
from app.schemas.survival import StreakInfo
from app.services.survival import SurvivalService

router = APIRouter()


@router.post('/create_or_resume', response_model=SurvivalQuestionResponse)
async def start_survival_run(
    payload: CreateOrResumeRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    survival_service: Annotated[SurvivalService, Depends(get_survival_service)],
) -> SurvivalQuestionResponse:
    """Start a new survival run.

    If the user has an active run, it is ended first.
    Returns the first question with a 40-second timer.
    """
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, start_survival_run.__qualname__)
    span.set_attribute(api_attrs.QUERY_PARAMS, f'run_id={payload.run_id}')

    response = await survival_service.create_or_resume_run(
        user_firebase_uid=current_user.firebase_uid,
        run_id=payload.run_id,
    )

    return response


@router.post('/answer', response_model=SurvivalAnswerResponse)
async def submit_survival_answer(
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


@router.get('/stats', response_model=SurvivalStatsResponse)
async def get_survival_stats(
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
async def get_survival_streak(
    current_user: Annotated[User, Depends(get_current_user)],
    survival_service: Annotated[SurvivalService, Depends(get_survival_service)],
) -> StreakInfo:
    """Get user's streak stats (current and best streak)."""
    span = trace.get_current_span()
    span.set_attribute(api_attrs.ACTION, get_survival_streak.__qualname__)

    return await survival_service.get_streak_stats(
        user_firebase_uid=current_user.firebase_uid,
    )

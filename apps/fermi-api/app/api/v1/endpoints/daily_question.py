"""Daily Question endpoints."""

from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, Depends, Path, Query
from fermi_db.models.user import User
from google.cloud.firestore_v1.async_client import AsyncClient

from app.api.v1.auth_deps import get_current_user
from app.api.v1.dependencies import (
    get_daily_question_service,
    get_firestore_client,
)
from app.services.daily_question.schemas import (
    DQAnswerRequest,
    DQEndResponse,
    DQLiteArchiveResponse,
    DQQuestionResponse,
    DQResultsResponse,
    DQSubmitResponse,
)
from app.services.daily_question.service import DailyQuestionService

router = APIRouter()


@router.post('/start', response_model=DQQuestionResponse)
async def start_question(
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
) -> DQQuestionResponse:
    """Start the daily question for the current user.

    Returns the question with the answer deadline.
    User has 30 seconds (or until window end, whichever is sooner) to answer.
    The DQ must be ACTIVE (12PM - 2AM UTC) for users to start.
    """
    return await dq_service.start_question(
        user_firebase_uid=current_user.firebase_uid,
        firestore_client=firestore_client,
    )


@router.post('/answer', response_model=DQSubmitResponse)
async def submit_answer(
    payload: DQAnswerRequest,
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
) -> DQSubmitResponse:
    """Submit an answer for the daily question.

    Must be called within the answer deadline (30s + 5s grace after starting,
    or before window end + 20s grace, whichever is sooner).
    """
    return await dq_service.submit_answer(
        user_firebase_uid=current_user.firebase_uid,
        answer=payload.answer,
        firestore_client=firestore_client,
    )


@router.get('/results', response_model=DQResultsResponse)
async def get_results(
    current_user: Annotated[User, Depends(get_current_user)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
) -> DQResultsResponse:
    """Get results for today's daily question.

    Only available after the DQ is CLOSED (after 2AM UTC next day).
    Returns user's score, rank, and leaderboard.
    """
    return await dq_service.get_results(
        user_firebase_uid=current_user.firebase_uid,
    )


@router.get('/results/{question_date}', response_model=DQResultsResponse)
async def get_results_for_date(
    current_user: Annotated[User, Depends(get_current_user)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
    question_date: str = Path(
        ...,
        pattern=r'^\d{4}-\d{2}-\d{2}$',
        description='Date in YYYY-MM-DD format',
    ),
) -> DQResultsResponse:
    """Get results for a specific daily question by date.

    Use this to view results for past daily questions.
    Only available for CLOSED DQs.
    """
    parsed_date = datetime.strptime(question_date, '%Y-%m-%d').date()
    return await dq_service.get_results_for_date(
        user_firebase_uid=current_user.firebase_uid,
        question_date=parsed_date,
    )


@router.get('/archive/week', response_model=DQLiteArchiveResponse)
async def get_archive_week(
    current_user: Annotated[User, Depends(get_current_user)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
) -> DQLiteArchiveResponse:
    """Get lite archive for the DQ carousel (past 7 days + today).

    Returns a lightweight response with dates and participation status.
    Use this for the main screen DQ carousel.
    """
    return await dq_service.get_lite_archive_week(
        user_firebase_uid=current_user.firebase_uid,
    )


@router.get('/archive/month', response_model=DQLiteArchiveResponse)
async def get_archive_month(
    current_user: Annotated[User, Depends(get_current_user)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
    year: int = Query(..., ge=2020, le=2100, description='Year (e.g., 2024)'),
    month: int = Query(..., ge=1, le=12, description='Month (1-12)'),
) -> DQLiteArchiveResponse:
    """Get lite archive for a specific month (calendar view).

    Returns a lightweight response with dates and participation status.
    Use this for the archive calendar sheet.
    """
    return await dq_service.get_lite_archive_month(
        user_firebase_uid=current_user.firebase_uid,
        year=year,
        month=month,
    )


@router.post('/close_and_schedule', response_model=DQEndResponse)
async def close_and_schedule_dq(
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
) -> DQEndResponse:
    """End the active DQ and schedule the next one.

    Called by Cloud Scheduler at 2AM UTC to:
    1. Close the DQ document in Firestore
    2. Close the DQ entry in the database
    3. Compute and update participant ranks
    4. Schedule the next day's DQ
    5. Set results_ready in Firestore

    This endpoint has no user authentication as it's called by Cloud Scheduler.
    In production, Cloud Run ingress rules and IAM protect this endpoint.
    """
    return await dq_service.close_active_and_schedule_new_dq(
        firestore_client=firestore_client,
    )


@router.post('/activate')
async def activate_dq(
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
) -> None:
    """Activate the scheduled DQ for this date. This is invoked by a scheduled job at
    12PM UTC.
    """
    await dq_service.activate_scheduled_dq(firestore_client=firestore_client)

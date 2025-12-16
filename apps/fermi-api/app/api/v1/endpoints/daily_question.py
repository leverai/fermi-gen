"""Daily Question endpoints."""

from typing import Annotated

from fastapi import APIRouter, Depends
from fermi_db.models.user import User
from google.cloud.firestore_v1.async_client import AsyncClient

from app.api.v1.auth_deps import get_current_user
from app.api.v1.dependencies import (
    get_daily_question_service,
    get_firestore_client,
)
from app.services.daily_question.schemas import (
    DQAnswerRequest,
    DQHistoryResponse,
    DQQuestionResponse,
    DQResultsResponse,
    DQStatusResponse,
    DQSubmitResponse,
)
from app.services.daily_question.service import DailyQuestionService

router = APIRouter()


@router.get('/status', response_model=DQStatusResponse)
async def get_status(
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
) -> DQStatusResponse:
    """Get the current daily question status.

    Returns window status, user status, and timing information.
    Frontend should use this for initial state and Firestore for real-time updates.
    """
    return await dq_service.get_status(
        user_firebase_uid=current_user.firebase_uid,
        firestore_client=firestore_client,
    )


@router.post('/start', response_model=DQQuestionResponse)
async def start_question(
    current_user: Annotated[User, Depends(get_current_user)],
    firestore_client: Annotated[AsyncClient, Depends(get_firestore_client)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
) -> DQQuestionResponse:
    """Start the daily question for the current user.

    Returns the question with the answer deadline.
    User has 30 seconds (or until 8 PM CT, whichever is sooner) to answer.
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
    or before 8 PM CT + 20s grace, whichever is sooner).
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

    Only available after 8 PM CT when the window closes.
    Returns user's score, rank, and leaderboard.
    """
    return await dq_service.get_results(
        user_firebase_uid=current_user.firebase_uid,
    )


@router.get('/history', response_model=DQHistoryResponse)
async def get_history(
    current_user: Annotated[User, Depends(get_current_user)],
    dq_service: Annotated[DailyQuestionService, Depends(get_daily_question_service)],
    limit: int = 30,
) -> DQHistoryResponse:
    """Get the user's daily question history.

    Returns past DQ results with scores and ranks.
    """
    return await dq_service.get_history(
        user_firebase_uid=current_user.firebase_uid,
        limit=limit,
    )

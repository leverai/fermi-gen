"""Daily Question service.

Orchestrates the Daily Question game mode, including:
- Getting DQ status
- Starting questions for users
- Submitting answers
- Getting results
"""

import logging
from typing import TYPE_CHECKING

from fastapi import HTTPException, status
from fermi_core.utils import utcnow_naive
from fermi_db.schemas import AnswerBare, DailyQuestionStatus
from pydantic import ValidationError

from app.services.daily_question.firestore_writer import DQFirestoreWriter
from app.services.daily_question.schemas import (
    DQHistoryResponse,
    DQLeaderboardEntry,
    DQQuestionData,
    DQQuestionResponse,
    DQResultsResponse,
    DQStatusResponse,
    DQSubmitResponse,
    DQUserSession,
    DQUserStatus,
    DQWindowStatus,
)
from app.services.daily_question.timing import (
    get_answer_deadline,
    get_todays_date_central,
    get_window_for_date_utc,
    is_window_open,
    is_within_ad_grace,
    seconds_until,
)
from app.services.scoring import ScoringService

if TYPE_CHECKING:
    from fermi_db import DatabaseClient
    from google.cloud.firestore_v1 import AsyncClient

logger = logging.getLogger(__name__)


class DailyQuestionService:
    """Service for Daily Question game mode operations."""

    def __init__(self, db_client: 'DatabaseClient') -> None:
        """Initialize the service.

        Args:
            db_client: The database client.

        """
        self._db = db_client
        self._scoring = ScoringService()

    async def get_status(
        self,
        user_firebase_uid: str,
        firestore_client: 'AsyncClient',
    ) -> DQStatusResponse:
        """Get the current daily question status.

        Args:
            user_firebase_uid: The user's Firebase UID.
            firestore_client: Firestore client.

        Returns:
            Status response with window and user status.

        """
        now_utc = utcnow_naive()
        today = get_todays_date_central(now_utc)
        window_start_utc, window_end_utc = get_window_for_date_utc(today)

        # Determine window status
        if now_utc < window_start_utc:
            return DQStatusResponse(
                window_status=DQWindowStatus.NOT_STARTED,
                question_date=today.strftime('%Y-%m-%d'),
            )

        if now_utc > window_end_utc:
            # Check if there's a DQ for today with results
            dq = await self._db.daily_questions.get_dq_for_date(today)
            has_results = dq is not None and dq.status == DailyQuestionStatus.CLOSED

            # Check user status
            user_status = DQUserStatus.MISSED
            if dq:
                assert dq.id is not None, 'DQ fetched from DB must have an ID'
                user_answer = await self._db.dq_answers.get_user_answer(
                    dq.id,
                    user_firebase_uid,
                )
                if user_answer:
                    user_status = DQUserStatus.SUBMITTED

            return DQStatusResponse(
                window_status=DQWindowStatus.CLOSED,
                question_date=today.strftime('%Y-%m-%d'),
                user_status=user_status,
                has_results=has_results,
            )

        # Window is active
        dq = await self._db.daily_questions.get_dq_for_date(today)
        if not dq:
            # No DQ scheduled for today
            return DQStatusResponse(
                window_status=DQWindowStatus.NOT_STARTED,
                question_date=today.strftime('%Y-%m-%d'),
            )

        # Check user status
        fs_writer = DQFirestoreWriter(firestore_client)
        user_session = await fs_writer.get_user_session(today, user_firebase_uid)

        user_status = DQUserStatus.NOT_STARTED
        if user_session:
            if user_session.get('submitted'):
                user_status = DQUserStatus.SUBMITTED
            else:
                user_status = DQUserStatus.IN_PROGRESS

        return DQStatusResponse(
            window_status=DQWindowStatus.ACTIVE,
            seconds_until_window_end=seconds_until(window_end_utc, now_utc),
            question_date=today.strftime('%Y-%m-%d'),
            user_status=user_status,
            has_results=False,
        )

    async def start_question(
        self,
        user_firebase_uid: str,
        firestore_client: 'AsyncClient',
    ) -> DQQuestionResponse:
        """Start the daily question for a user.

        Args:
            user_firebase_uid: The user's Firebase UID.
            firestore_client: Firestore client.

        Returns:
            The question response with deadline info.

        Raises:
            HTTPException: If window is closed or user already started.

        """
        now_utc = utcnow_naive()
        today = get_todays_date_central(now_utc)
        window_start_utc, window_end_utc = get_window_for_date_utc(today)

        # Check window is open
        if not is_window_open(now_utc, window_end_utc):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='Daily question window is closed.',
            )

        # Get today's DQ
        dq = await self._db.daily_questions.get_dq_for_date(today)
        if not dq:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail='No daily question available for today.',
            )

        # Check if user already started
        fs_writer = DQFirestoreWriter(firestore_client)
        user_session = await fs_writer.get_user_session(today, user_firebase_uid)

        if user_session:
            if user_session.get('submitted'):
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail='You have already submitted an answer.',
                )
            # User already started but hasn't submitted
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='You have already started this question.',
            )

        # Get the question from fermi table
        fermi = await self._db.fermi.get_by_uid(dq.question_uid)
        if not fermi:
            logger.error(
                'Fermi question not found for DQ %s (uid=%s)',
                dq.id,
                dq.question_uid,
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail='Question data not found.',
            )

        # Calculate answer deadline
        answer_deadline_utc = get_answer_deadline(now_utc, window_end_utc)

        # Record user start in Firestore
        await fs_writer.record_user_start(
            today,
            user_firebase_uid,
            now_utc,
            answer_deadline_utc,
        )

        logger.info(
            'User %s started DQ for %s, deadline: %s',
            user_firebase_uid,
            today,
            answer_deadline_utc,
        )

        return DQQuestionResponse(
            question=DQQuestionData(
                question_uid=str(fermi.uid),
                text=fermi.text,
                category=fermi.category,
                difficulty=fermi.difficulty,
                unit_hint=fermi.unit,
            ),
            answer_deadline_utc=answer_deadline_utc.isoformat(),
            seconds_to_answer=seconds_until(answer_deadline_utc, now_utc),
        )

    async def submit_answer(
        self,
        user_firebase_uid: str,
        answer: AnswerBare,
        firestore_client: 'AsyncClient',
    ) -> DQSubmitResponse:
        """Submit an answer for the daily question.

        Args:
            user_firebase_uid: The user's Firebase UID.
            answer: The user's answer.
            firestore_client: Firestore client.

        Returns:
            Submit response with score.

        Raises:
            HTTPException: If deadline passed or user hasn't started.

        """
        now_utc = utcnow_naive()
        today = get_todays_date_central(now_utc)
        _, window_end_utc = get_window_for_date_utc(today)

        # Get today's DQ
        dq = await self._db.daily_questions.get_dq_for_date(today)
        if not dq:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail='No daily question available for today.',
            )

        # Check if user has started
        fs_writer = DQFirestoreWriter(firestore_client)
        user_session = await fs_writer.get_user_session(today, user_firebase_uid)

        if not user_session:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='You must start the question first.',
            )

        # Validate and parse session data with Pydantic
        try:
            session = DQUserSession.model_validate(user_session)
        except ValidationError as e:
            logger.error('Session data corrupted for user %s: %s', user_firebase_uid, e)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail='Session data corrupted.',
            ) from e

        if session.submitted:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='You have already submitted an answer.',
            )

        # Check if within grace period
        if not is_within_ad_grace(now_utc, session.answer_deadline):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='Answer deadline has passed.',
            )

        # Get the question for scoring
        assert dq.id is not None, 'DQ fetched from DB must have an ID'
        fermi = await self._db.fermi.get_by_uid(dq.question_uid)
        if not fermi:
            logger.error(
                'Fermi question not found for DQ %s (uid=%s)',
                dq.id,
                dq.question_uid,
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail='Question data not found.',
            )

        # Compute score
        correct_answer: AnswerBare = {
            'number': fermi.number,
            'unit': fermi.unit,
        }
        score = self._scoring.calculate_score(answer, correct_answer)

        # Store answer in database
        await self._db.dq_answers.submit_answer(
            daily_question_id=dq.id,
            user_firebase_uid=user_firebase_uid,
            answer_number=answer['number'],
            answer_unit=answer.get('unit'),
            score=score,
            started_at=session.started_at,
            submitted_at=now_utc,
        )

        # Mark as submitted in Firestore
        await fs_writer.mark_user_submitted(today, user_firebase_uid)

        logger.info(
            'User %s submitted DQ answer for %s, score: %s',
            user_firebase_uid,
            today,
            score,
        )

        return DQSubmitResponse(
            submitted=True,
            score=score,
            message='Answer submitted successfully. Results available after 8 PM CT.',
        )

    async def get_results(
        self,
        user_firebase_uid: str,
    ) -> DQResultsResponse:
        """Get results for a completed daily question.

        Args:
            user_firebase_uid: The user's Firebase UID.

        Returns:
            Results response with user rank and leaderboard.

        Raises:
            HTTPException: If results not available.

        """
        now_utc = utcnow_naive()
        today = get_todays_date_central(now_utc)

        # Get today's DQ
        dq = await self._db.daily_questions.get_dq_for_date(today)
        if not dq or dq.status != DailyQuestionStatus.CLOSED:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='Results are not yet available.',
            )

        # Get the question
        assert dq.id is not None, 'DQ fetched from DB must have an ID'
        fermi = await self._db.fermi.get_by_uid(dq.question_uid)
        if not fermi:
            logger.error(
                'Fermi question not found for DQ %s (uid=%s)',
                dq.id,
                dq.question_uid,
            )
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail='Question data not found.',
            )

        # Get user's answer
        user_answer = await self._db.dq_answers.get_user_answer(
            dq.id,
            user_firebase_uid,
        )

        # Get rank and participant count
        user_rank = await self._db.dq_answers.get_user_rank(
            dq.id,
            user_firebase_uid,
        )
        total_participants = await self._db.dq_answers.count_participants(
            dq.id,
        )

        # Get leaderboard
        leaderboard_entries = await self._db.dq_answers.get_leaderboard(
            dq.id,
            limit=10,
        )

        leaderboard = []
        for i, entry in enumerate(leaderboard_entries, 1):
            leaderboard.append(
                DQLeaderboardEntry(
                    rank=entry.rank or i,
                    display_name=None,  # Could look up user display name
                    score=entry.score,
                    time_taken_s=entry.time_taken_s,
                ),
            )

        return DQResultsResponse(
            question_date=today.strftime('%Y-%m-%d'),
            question_uid=str(fermi.uid),
            question_text=fermi.text,
            correct_answer={'number': fermi.number, 'unit': fermi.unit},
            user_answer=(
                {'number': user_answer.answer_number, 'unit': user_answer.answer_unit}
                if user_answer
                else None
            ),
            user_score=user_answer.score if user_answer else None,
            user_rank=user_rank,
            total_participants=total_participants,
            leaderboard=leaderboard,
        )

    async def get_history(
        self,
        user_firebase_uid: str,
        limit: int = 30,
    ) -> DQHistoryResponse:
        """Get user's DQ history.

        Args:
            user_firebase_uid: The user's Firebase UID.
            limit: Maximum number of items to return.

        Returns:
            History response with past DQ results.

        Note:
            This is a placeholder - would need a more complex query
            to efficiently fetch history across multiple DQs.

        """
        # TODO: Implement history query across multiple daily_questions
        # This would require a join between daily_question_answers and daily_questions
        return DQHistoryResponse(history=[])

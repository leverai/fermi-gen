"""Daily Question service.

Orchestrates the Daily Question game mode, including:
- Starting questions for users
- Submitting answers
- Getting results
- Lite archives for carousel and calendar views
"""

import datetime
import logging
from typing import TYPE_CHECKING

from fastapi import HTTPException, status
from fermi_core.units import get_unit_family
from fermi_core.utils import utcnow_naive
from fermi_db.schemas import AnswerBare, DailyQuestionStatus

from app.services.daily_question.firestore_writer import DQFirestoreWriter
from app.services.daily_question.schemas import (
    DQLeaderboardEntry,
    DQLiteArchiveResponse,
    DQQuestionData,
    DQQuestionResponse,
    DQResultsResponse,
    DQSubmitResponse,
)
from app.services.daily_question.timing import (
    get_answer_deadline,
    get_dq_date_for_utc,
    get_window_for_date_utc,
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
        today = get_dq_date_for_utc(now_utc)
        _, window_end_utc = get_window_for_date_utc(today)

        # Check window is open
        if now_utc >= window_end_utc:
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

        # Only allow starting if status is ACTIVE
        if dq.status != DailyQuestionStatus.ACTIVE:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='Daily question is not yet active.',
            )

        # Check if user already has a session or submitted an answer
        fs_writer = DQFirestoreWriter(firestore_client)
        user_session = await fs_writer.get_user_session(today, user_firebase_uid)

        if user_session:
            # User already has a session - check if they submitted
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

        # Check if user already answered in DB (session may have been deleted)
        assert dq.id is not None
        has_answered = await self._db.dq_answers.has_user_answered(
            dq.id,
            user_firebase_uid,
        )
        if has_answered:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='You have already submitted an answer.',
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

        # Get unit family for dimensional questions
        units = None
        if fermi.unit:
            try:
                units = get_unit_family(fermi.unit)
            except ValueError:
                logger.warning('Unknown unit for DQ: %s', fermi.unit)

        return DQQuestionResponse(
            question=DQQuestionData(
                question_uid=str(fermi.uid),
                text=fermi.text,
                category=fermi.category,
                difficulty=fermi.difficulty,
                units=units,
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
        today = get_dq_date_for_utc(now_utc)

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

        if user_session['submitted']:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='You have already submitted an answer.',
            )

        # Check if within grace period
        if not is_within_ad_grace(
            now_utc,
            user_session['answer_deadline'],
        ):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='Answer deadline has passed.',
            )

        # Get the question for scoring
        assert dq.id is not None
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
            started_at=user_session['started_at'],
            submitted_at=now_utc,
        )

        # Commit the database transaction
        await self._db.session.commit()

        # Mark user session as submitted in Firestore (keep for tracking)
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
            message='Answer submitted successfully. Results available when DQ closes.',
        )

    async def get_results_for_date(
        self,
        user_firebase_uid: str,
        question_date: datetime.date,
    ) -> DQResultsResponse:
        """Get results for a completed daily question.

        Args:
            user_firebase_uid: The user's Firebase UID.
            question_date: The date of the DQ to get results for.

        Returns:
            Results response with user rank and leaderboard.

        Raises:
            HTTPException: If results not available.

        """
        dq = await self._db.daily_questions.get_dq_for_date(question_date)
        if not dq:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail=f'No daily question found for {question_date}.',
            )

        if dq.status != DailyQuestionStatus.CLOSED:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='Results are not yet available for this question.',
            )

        # Get the question
        assert dq.id is not None
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

        # Get leaderboard
        leaderboard_entries = await self._db.dq_answers.get_leaderboard(
            dq.id,
            limit=10,
        )
        leaderboard = [
            DQLeaderboardEntry(
                rank=entry.rank or i,
                display_name=None,
                score=entry.score,
                time_taken_s=entry.time_taken_s,
            )
            for i, entry in enumerate(leaderboard_entries, 1)
        ]

        # Get user's answer and rank, if any
        user_answer = await self._db.dq_answers.get_user_answer(
            dq.id,
            user_firebase_uid,
        )
        if not user_answer:
            user_answer_bare = None
            user_rank = None
        else:
            user_answer_bare = {
                'number': user_answer.answer_number,
                'unit': user_answer.answer_unit,
            }
            user_rank = await self._db.dq_answers.get_user_rank(
                dq.id,
                user_firebase_uid,
            )

        # Get total participants
        total_participants = await self._db.dq_answers.count_participants(dq.id)

        return DQResultsResponse(
            question_date=question_date.strftime('%Y-%m-%d'),
            question_uid=str(fermi.uid),
            question_text=fermi.text,
            correct_answer={'number': fermi.number, 'unit': fermi.unit},
            user_answer=user_answer_bare,
            user_score=user_answer.score if user_answer else None,
            user_rank=user_rank,
            total_participants=total_participants,
            leaderboard=leaderboard,
        )

    async def get_results(
        self,
        user_firebase_uid: str,
    ) -> DQResultsResponse:
        """Get results for today's daily question.

        Args:
            user_firebase_uid: The user's Firebase UID.

        Returns:
            Results response with user rank and leaderboard.

        Raises:
            HTTPException: If DQ not found or results not available.

        """
        utc_now = utcnow_naive()
        today = get_dq_date_for_utc(utc_now)
        return await self.get_results_for_date(user_firebase_uid, today)

    async def get_lite_archive_week(
        self,
        user_firebase_uid: str,
    ) -> DQLiteArchiveResponse:
        """Get lite archive for the DQ carousel (past 7 days + today).

        Returns a lightweight response with just dates and participation status.
        Frontend should use this for the carousel view.

        Args:
            user_firebase_uid: The user's Firebase UID.

        Returns:
            Lite archive response with items and today's date.

        """
        utc_now = utcnow_naive()
        today = get_dq_date_for_utc(utc_now)

        items = await self._db.daily_questions.get_lite_archive_for_week(
            user_firebase_uid,
            today,
        )

        return DQLiteArchiveResponse(
            items=items,
            today=today.strftime('%Y-%m-%d'),
        )

    async def get_lite_archive_month(
        self,
        user_firebase_uid: str,
        year: int,
        month: int,
    ) -> DQLiteArchiveResponse:
        """Get lite archive for a specific month (calendar view).

        Returns a lightweight response with just dates and participation status.
        Frontend should use this for the archive calendar sheet.

        Args:
            user_firebase_uid: The user's Firebase UID.
            year: The year (e.g., 2024).
            month: The month (1-12).

        Returns:
            Lite archive response with items and today's date.

        """
        utc_now = utcnow_naive()
        today = get_dq_date_for_utc(utc_now)

        items = await self._db.daily_questions.get_lite_archive_for_month(
            user_firebase_uid,
            year,
            month,
        )

        return DQLiteArchiveResponse(
            items=items,
            today=today.strftime('%Y-%m-%d'),
        )

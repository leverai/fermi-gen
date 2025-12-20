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
from fermi_core.units import convert_answer_to_user_unit, get_unit_family, get_unit_info
from fermi_core.utils import utcnow_naive
from fermi_db.schemas import AnswerBare, DailyQuestionStatus

from app.services.daily_question.firestore_writer import DQFirestoreWriter
from app.services.daily_question.schemas import (
    DQAnswer,
    DQEndResponse,
    DQLeaderboardEntry,
    DQLiteArchiveResponse,
    DQPlayer,
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
        seconds_remaining = seconds_until(answer_deadline_utc, now_utc)
        logger.info(
            '[DQ Service] Deadline calculation: now=%s, window_end=%s, '
            'answer_deadline=%s, seconds_to_answer=%s',
            now_utc,
            window_end_utc,
            answer_deadline_utc,
            seconds_remaining,
        )

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
            answer_deadline_utc=answer_deadline_utc.isoformat() + 'Z',
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

        # Extract unique Firebase UIDs from leaderboard entries
        firebase_uids = [entry.user_firebase_uid for entry in leaderboard_entries]

        # Batch-fetch user info for all leaderboard players
        users_map: dict[str, dict[str, str | None]] = {}
        if firebase_uids:
            users = await self._db.users.get_by_firebase_uids(firebase_uids)
            users_map = {
                user.firebase_uid: {
                    'display_name': user.display_name,
                    'avatar_url': user.picture,
                }
                for user in users
            }

        # Construct leaderboard with player info
        leaderboard = [
            DQLeaderboardEntry(
                rank=entry.rank or i,
                player=DQPlayer(
                    display_name=users_map.get(entry.user_firebase_uid, {}).get(
                        'display_name',
                    ),
                    avatar_url=users_map.get(entry.user_firebase_uid, {}).get(
                        'avatar_url',
                    ),
                )
                if entry.user_firebase_uid in users_map
                else None,
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
            user_answer_dq = None
            user_rank = None
        else:
            # Get unit info for user's answer
            user_unit_info = None
            if user_answer.answer_unit:
                try:
                    user_unit_info = get_unit_info(user_answer.answer_unit)
                except ValueError:
                    logger.warning('Unknown unit: %s', user_answer.answer_unit)
            user_answer_dq = DQAnswer(
                number=user_answer.answer_number,
                unit=user_unit_info,
            )
            user_rank = await self._db.dq_answers.get_user_rank(
                dq.id,
                user_firebase_uid,
            )

        # Get correct answer in user's unit (if any)
        if user_answer and user_answer.answer_unit:
            correct_answer = convert_answer_to_user_unit(
                user_answer.answer_unit,
                {'number': fermi.number, 'unit': fermi.unit},
            )
            correct_answer_dq = DQAnswer(
                number=correct_answer['number'],
                unit=get_unit_info(correct_answer['unit']),
            )
        else:
            correct_answer_dq = DQAnswer(
                number=fermi.number,
                unit=None,
            )

        # Get total participants
        total_participants = await self._db.dq_answers.count_participants(dq.id)

        return DQResultsResponse(
            question_date=question_date.strftime('%Y-%m-%d'),
            question_uid=str(fermi.uid),
            question_text=fermi.text,
            correct_answer=correct_answer_dq,
            user_answer=user_answer_dq,
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

    async def close_active_and_schedule_new_dq(
        self,
        firestore_client: 'AsyncClient',
    ) -> DQEndResponse:
        """Close the active DQ (if any) and schedule the next one.

        This is designed to handle the first run gracefully - if no active DQ exists,
        the close step is skipped and only scheduling happens.
        """
        now_utc = utcnow_naive()
        today = get_dq_date_for_utc(now_utc)
        fs_writer = DQFirestoreWriter(firestore_client)

        # Try to close the active DQ if one exists
        active_date = await self._db.daily_questions.get_active_dq_date()
        closed_date: str | None = None
        participants_ranked = 0

        if active_date:
            closed_date, participants_ranked = await self._close_dq_for_date(
                active_date,
                fs_writer,
            )
        else:
            logger.info('No active DQ to close, proceeding to schedule new DQ')

        # Schedule the new DQ (either the day after the closed one, or today)
        next_date = active_date + datetime.timedelta(days=1) if active_date else today
        next_date_str, next_question_uid = await self._schedule_new_dq_for_date(
            next_date,
            fs_writer,
        )

        return DQEndResponse(
            closed_date=closed_date,
            participants_ranked=participants_ranked,
            next_date=next_date_str,
            next_question_uid=next_question_uid,
        )

    async def _close_dq_for_date(
        self,
        question_date: datetime.date,
        fs_writer: DQFirestoreWriter,
    ) -> tuple[str | None, int]:
        """Close the DQ for a given date.

        Steps:
        1. Close the Firestore document
        2. Close the database entry (set status to CLOSED)
        3. Compute and update participant ranks
        4. Set results_ready in Firestore

        Args:
            question_date: The date of the DQ to close.
            fs_writer: Firestore writer instance.

        Returns:
            Tuple of (closed_date as string, participants_ranked count).
            Returns (None, 0) if DQ doesn't exist or is already closed.

        """
        dq = await self._db.daily_questions.get_dq_for_date(question_date)
        assert dq is not None
        assert dq.id is not None

        # Step 1: Close Firestore document
        try:
            await fs_writer.close_dq_document(question_date)
            logger.info('Closed Firestore document for %s', question_date)
        except Exception:
            logger.exception(
                'Failed to close Firestore document for %s',
                question_date,
            )

        # Step 2: Close DB entry
        await self._db.daily_questions.update_dq_status(
            dq.id,
            DailyQuestionStatus.CLOSED,
        )
        logger.info('Closed DB entry for DQ %s', dq.id)

        # Step 3: Compute and update ranks
        participants_ranked = await self._db.dq_answers.compute_and_update_ranks(dq.id)
        logger.info('Computed ranks for %d participants', participants_ranked)

        # Commit DB changes for closing
        await self._db.session.commit()

        # Step 4: Set results ready in Firestore
        try:
            await fs_writer.set_results_ready(question_date)
            logger.info('Set results_ready for %s', question_date)
        except Exception:
            logger.exception('Failed to set results_ready for %s', question_date)

        return question_date.strftime('%Y-%m-%d'), participants_ranked

    async def _schedule_new_dq_for_date(
        self,
        next_date: datetime.date,
        fs_writer: DQFirestoreWriter,
    ) -> tuple[str | None, str | None]:
        """Schedule a new DQ for the given date.

        Steps:
        1. Schedule the DQ in the database
        2. Create the Firestore document

        Args:
            next_date: The date to schedule the DQ for.
            fs_writer: Firestore writer instance.

        Returns:
            Tuple of (next_date as string, next_question_uid).
            Returns (None, None) if scheduling fails.

        """
        next_window_start, next_window_end = get_window_for_date_utc(next_date)
        next_question_uid: str | None = None
        scheduled_date: datetime.date | None = next_date

        try:
            next_dq = await self._db.daily_questions.schedule_dq_for_date(
                next_date,
                next_window_start,
                next_window_end,
            )
            # Commit DB changes for scheduling
            await self._db.session.commit()
            next_question_uid = str(next_dq.question_uid)
            logger.info(
                'Scheduled DQ for %s with question %s',
                next_date,
                next_question_uid,
            )
        except ValueError:
            logger.exception('Could not schedule next DQ')
            scheduled_date = None

        if scheduled_date:
            # Create Firestore document for next DQ
            try:
                assert next_question_uid is not None
                await fs_writer.create_dq_document(
                    scheduled_date,
                    next_question_uid,
                    next_window_start,
                    next_window_end,
                )
                logger.info('Created Firestore document for %s', scheduled_date)
            except Exception:
                logger.exception(
                    'Failed to create Firestore document for %s',
                    scheduled_date,
                )

        return (
            scheduled_date.strftime('%Y-%m-%d') if scheduled_date else None,
            next_question_uid,
        )

    async def _activate_scheduled_dq_for_date(
        self,
        question_date: datetime.date,
        firestore_client: 'AsyncClient',
    ) -> None:
        """Activate the scheduled DQ for a given date.
        1. Call `update_dq_status` @daily_question_repository.py#L124-142  to activate
        the scheduled DQ.
        2. Updates the DQ doc status to ACTIVE.
        """
        # Get the DQ for the given date to activate it.
        dq = await self._db.daily_questions.get_dq_for_date(question_date)
        assert dq is not None
        assert dq.id is not None
        if not dq:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail='No Scheduled DQ found for the given date.',
            )
        if dq.status == DailyQuestionStatus.ACTIVE:
            logger.warning('DQ for %s is already active', question_date)
            return
        if dq.status == DailyQuestionStatus.CLOSED:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail='DQ for %s is closed',
            )
        await self._db.daily_questions.update_dq_status(
            dq.id,
            DailyQuestionStatus.ACTIVE,
        )
        await self._db.session.commit()

        fs_writer = DQFirestoreWriter(firestore_client)
        try:
            await fs_writer.activate_dq_document(question_date)
            logger.info('Set active for %s', question_date)
        except Exception as exc:
            logger.exception('Failed to set active for %s', question_date)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail='Failed to set active for %s',
            ) from exc

    async def activate_scheduled_dq(self, firestore_client: 'AsyncClient') -> None:
        """Activate the scheduled DQ for this date. This is invoked by a scheduled job
        at 12PM UTC.
        """
        now_utc = utcnow_naive()
        today = get_dq_date_for_utc(now_utc)
        await self._activate_scheduled_dq_for_date(today, firestore_client)

"""Survival Mode service for gameplay logic."""

import logging
import uuid
from datetime import timedelta
from typing import TYPE_CHECKING, cast

from fastapi import HTTPException, Request, status
from fermi_core.units import convert_answer_to_user_unit, get_unit_family
from fermi_core.utils import utcnow_naive
from fermi_db.models import AnswerEvent, Fermi
from fermi_db.schemas import AnswerBare, GameMode, QuestionCategory, QuestionDifficulty
from opentelemetry import trace

import app.logging.attributes as attrs
from app.schemas.survival import (
    ContinueWithAdResponse,
    LeaderboardEntry,
    LeaderboardPeriod,
    LeaderboardResponse,
    StreakInfo,
    SurvivalAnswerResponse,
    SurvivalQuestionData,
    SurvivalQuestionResponse,
    SurvivalRunSummary,
    SurvivalStatsResponse,
)
from app.services.game.ranks import get_rank_picture_for_percentile
from app.services.scoring import ScoringService, compute_p50_ratio

logger = logging.getLogger(__name__)

if TYPE_CHECKING:
    from fermi_db import DatabaseClient
    from fermi_db.models.survival import SurvivalRun

    from app.schemas.game import ScoreQuantiles


# Constants
SURVIVAL_TIME_LIMIT_SECONDS = 40
GRACE_PERIOD_SECONDS = 20
GRACE_PERIOD = timedelta(seconds=GRACE_PERIOD_SECONDS)

# Free tier survival run limit (per calendar day)
FREE_SURVIVAL_RUNS_PER_DAY = 3


class SurvivalService:
    """Service for survival mode gameplay logic."""

    def __init__(self, db_client: 'DatabaseClient') -> None:
        """Initialize the service with a database client."""
        self._db = db_client
        self._scoring = ScoringService()

    async def _get_active_run(self, run_id: int) -> 'SurvivalRun':
        """Get an active run by id."""
        run = await self._db.survival_runs.get_run_by_id(run_id)
        if run is None:
            raise ValueError(f'Run {run_id} not found')
        if run.ended_at:
            raise ValueError(f'Run {run_id} already ended at {run.ended_at}')
        assert run.current_question_uid, 'This should not happen.'
        return run

    async def create_or_resume_run(
        self,
        user_firebase_uid: str,
        run_id: int | None = None,
        *,
        is_pro: bool = False,
    ) -> SurvivalQuestionResponse:
        """Create a new run or resume an existing one.

        Args:
            user_firebase_uid: User's Firebase UID.
            run_id: Optional run ID to resume.
            is_pro: Whether user has Pro subscription (unlimited runs).

        Returns:
            Question response with run info.

        Raises:
            HTTPException: 403 if daily limit reached (free users only).

        """
        span = trace.get_current_span()

        # Get or create the run. Try to get by id.
        # If not found, try to find from user id. If not found, create a new run.
        run: SurvivalRun | None = None
        if run_id:
            run = await self._get_active_run(run_id)
            span.set_attribute(attrs.SURVIVAL_RUN_ID, run_id)
        else:
            run = await self._db.survival_runs.get_active_run(
                user_firebase_uid=user_firebase_uid,
            )

        # At this point, we either got it by id, found it by player, or will create it.
        # Let's fetch the next question
        question = await self._get_random_question(
            user_firebase_uid=user_firebase_uid,
        )

        deadline = utcnow_naive() + timedelta(seconds=SURVIVAL_TIME_LIMIT_SECONDS)
        if run:
            # Update run with new question
            run = await self._db.survival_runs.set_current_question(
                run_id=run.id,
                question_uid=str(question.uid),
                deadline=deadline,
            )
        else:
            # Creating new run - check limits for free users
            if not is_pro:
                remaining = await self._db.survival_runs.get_runs_remaining_today(
                    user_firebase_uid=user_firebase_uid,
                    limit=FREE_SURVIVAL_RUNS_PER_DAY,
                )
                if remaining <= 0:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail='Daily survival run limit reached',
                    )

            # Create new run with the new question
            run = await self._db.survival_runs.create_run(
                user_firebase_uid=user_firebase_uid,
                question_uid=str(question.uid),
                deadline=deadline,
            )

        # We have a run now with the new question. Time to return to user
        assert run.id, 'This should not happen.'
        max_ad_saves = 1
        question_data = await self._build_question_data(question, user_firebase_uid)
        return SurvivalQuestionResponse(
            run_id=run.id,
            question_number=run.questions_answered + 1,
            question=question_data,
            time_limit_seconds=SURVIVAL_TIME_LIMIT_SECONDS,
            answer_deadline_utc=deadline.isoformat() + 'Z',
            streak=run.streak,
            can_use_ad_save=run.ad_saves_used < max_ad_saves,
        )

    async def submit_answer(
        self,
        user_firebase_uid: str,
        run_id: int,
        answer: AnswerBare,
    ) -> SurvivalAnswerResponse:
        """Submit an answer for the current question.

        1. Get and validate run
        1.5 Validate deadline
        2. Get question, compute score and percentile -> pass/fail
        3. Update run record
        4. Update answer events and user history
        5. Increment XP
        6. Return response

        Records the answer, updates history, and determines pass/fail.
        """
        span = trace.get_current_span()
        span.set_attribute(attrs.SURVIVAL_PLAYER_ANSWER, str(answer))

        # 1. Get and validate run
        run = await self._db.survival_runs.get_run_by_id(run_id)
        if run is None:
            raise ValueError(f'Run {run_id} not found')

        # Set OTel attributes for run context
        span.set_attribute(attrs.SURVIVAL_RUN_ID, run_id)
        span.set_attribute(attrs.SURVIVAL_QUESTIONS_ANSWERED, run.questions_answered)

        if run.user_firebase_uid != user_firebase_uid:
            raise ValueError('Run does not belong to user')
        if run.ended_at:
            raise ValueError('Run is already completed')

        # 1.5 Validate deadline
        if run.current_deadline is None:
            raise ValueError('Run is not active')
        if utcnow_naive() - GRACE_PERIOD > run.current_deadline:
            raise ValueError('Run is past deadline')

        # 2. Get question, compute score and percentile -> pass/fail
        correct_answer_w_snippet = await self._db.fermi.get_answer_with_snippet_by_uid(
            uuid.UUID(run.current_question_uid),
        )
        assert correct_answer_w_snippet, 'This should not happen.'
        correct_answer = AnswerBare(
            number=correct_answer_w_snippet['number'],
            unit=correct_answer_w_snippet['unit'],
        )
        span.set_attribute(attrs.QUESTION_UID, str(run.current_question_uid))
        score = self._scoring.calculate_score(answer, correct_answer)
        quantiles = await self._db.answers.get_question_quantiles(
            uuid.UUID(run.current_question_uid),
        )
        quantiles_dict = cast(
            'ScoreQuantiles',
            quantiles.model_dump(exclude={'question_uid'}),
        )
        quantile = self._scoring.get_score_quantile(score, quantiles_dict)
        pass_threshold = quantiles.p50
        passed = score >= pass_threshold
        span.set_attribute(attrs.SURVIVAL_SCORE, score)
        span.set_attribute(attrs.SURVIVAL_PASSED, passed)

        # Update run record - Ends run if failed
        run = await self._db.survival_runs.submit_score(run_id, score, passed=passed)
        assert run.id, 'This should not happen.'
        span.set_attribute(attrs.SURVIVAL_TOTAL_SCORE, run.total_score)

        # Convert correct answer to player's unit if applicable
        if answer['unit']:
            converted_answer = convert_answer_to_user_unit(
                player_unit_id=answer['unit'],
                correct_answer=correct_answer,
            )
        else:
            converted_answer = correct_answer

        # 4. Update answer events and user history
        answer_event = AnswerEvent(
            question_uid=uuid.UUID(run.current_question_uid),
            # TODO: remove cat and diff from AnswerEvent
            question_difficulty=QuestionDifficulty.MEDIUM,
            question_category=QuestionCategory.OTHER,
            user_firebase_id=user_firebase_uid,
            game_id=str(run_id),
            answer=answer,
            correct_answer=converted_answer,
            score_number=score,
            score_quantile=quantile,
            game_mode=GameMode.SURVIVAL,
        )
        await self._db.answers.add_answers([answer_event])
        await self._db.users_history.add_questions_to_users_history(
            user_ids=[user_firebase_uid],
            question_uids=[run.current_question_uid],
        )

        # Increment XP and points
        xp_increment = int(score // 100)
        if xp_increment > 0:
            await self._db.users.increment_xp(user_firebase_uid, xp_increment)
            await self._db.users.increment_points(user_firebase_uid, xp_increment)

        p50_ratio = compute_p50_ratio(pass_threshold)
        return SurvivalAnswerResponse(
            passed=passed,
            score=score,
            percentile=quantile * 100,
            pass_threshold=pass_threshold,
            p50_ratio=p50_ratio,
            correct_answer=correct_answer,
            converted_correct_answer=converted_answer,
            user_answer=answer,
            total_questions=run.questions_answered,
            total_score=run.total_score,
            run_summary=SurvivalRunSummary(
                run_id=run_id,
                questions_answered=run.questions_answered,
                streak=run.streak,
                total_score=run.total_score,
            ),
            ai_overview=correct_answer_w_snippet['ai_overview'],
        )

    async def continue_run_with_ad(
        self,
        user_firebase_uid: str,
        run_id: int,
    ) -> 'ContinueWithAdResponse':
        """Continue a failed survival run after watching an ad.

        Args:
            user_firebase_uid: User's Firebase UID.
            run_id: The run ID to continue.

        Returns:
            Response with next question data.

        Raises:
            HTTPException: 400 if run cannot be continued (not owner, not ended,
                          or ad saves exhausted).

        """
        span = trace.get_current_span()
        span.set_attribute(attrs.SURVIVAL_RUN_ID, run_id)

        # Get the run
        run = await self._db.survival_runs.get_run_by_id(run_id)
        if run is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail='Run not found',
            )

        # Validate ownership
        if run.user_firebase_uid != user_firebase_uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail='Run does not belong to user',
            )

        # Must be a completed (failed) run
        if not run.is_completed:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail='Run is still active',
            )

        # Check ad saves limit (max 1 per run)
        max_ad_saves = 1
        if run.ad_saves_used >= max_ad_saves:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail='Ad save already used for this run',
            )

        # Reopen the run
        run = await self._db.survival_runs.reopen_run_with_ad(run_id)
        span.set_attribute(attrs.SURVIVAL_QUESTIONS_ANSWERED, run.questions_answered)

        # Get a new question
        question = await self._get_random_question(user_firebase_uid=user_firebase_uid)

        # Set the new question and deadline
        deadline = utcnow_naive() + timedelta(seconds=SURVIVAL_TIME_LIMIT_SECONDS)
        run = await self._db.survival_runs.set_current_question(
            run_id=run.id,  # type: ignore
            question_uid=str(question.uid),
            deadline=deadline,
        )

        # Build response
        question_data = await self._build_question_data(question, user_firebase_uid)
        return ContinueWithAdResponse(
            run_id=run.id,  # type: ignore
            question_number=run.questions_answered + 1,
            question=question_data,
            time_limit_seconds=SURVIVAL_TIME_LIMIT_SECONDS,
            answer_deadline_utc=deadline.isoformat() + 'Z',
            streak=run.streak,
            can_use_ad_save=run.ad_saves_used < max_ad_saves,
        )

    async def get_stats(self, user_firebase_uid: str) -> SurvivalStatsResponse:
        """Get user's survival mode statistics."""
        total_runs = await self._db.survival_runs.count_user_runs(user_firebase_uid)
        total_questions = await self._db.survival_runs.get_user_total_questions(
            user_firebase_uid,
        )
        avg_streak = await self._db.survival_runs.get_user_average_streak(
            user_firebase_uid,
        )

        # Get best run
        best_run = await self._db.survival_runs.get_user_best_run(user_firebase_uid)
        best_streak = best_run.streak

        # Set OTel attributes for stats
        span = trace.get_current_span()
        span.set_attribute(attrs.SURVIVAL_TOTAL_RUNS, total_runs)
        span.set_attribute(attrs.SURVIVAL_BEST_STREAK, best_streak)

        return SurvivalStatsResponse(
            total_runs=total_runs,
            best_streak=best_streak,
            average_streak=avg_streak,
            total_questions_answered=total_questions,
        )

    async def get_streak_stats(self, user_firebase_uid: str) -> StreakInfo:
        """Get user's streak stats (current and best streak)."""
        best_streak = await self._db.survival_runs.get_user_best_streak(
            user_firebase_uid=user_firebase_uid,
        )
        current_streak = await self._db.survival_runs.get_current_streak(
            user_firebase_uid=user_firebase_uid,
        )
        return StreakInfo(
            best_streak=best_streak,
            current_streak=current_streak,
        )

    async def get_leaderboard(
        self,
        user_firebase_uid: str,
        page: int = 1,
        page_size: int = 25,
        period: LeaderboardPeriod = LeaderboardPeriod.weekly,
        request: Request | None = None,
    ) -> LeaderboardResponse:
        """Get paginated global streak leaderboard with current user's entry."""
        import datetime

        offset = (page - 1) * page_size

        # Compute date range based on period
        start_date: datetime.datetime | None = None
        end_date: datetime.datetime | None = None
        now = datetime.datetime.now(datetime.UTC).replace(tzinfo=None)

        if period == LeaderboardPeriod.weekly:
            # Start of current week (Monday 00:00 UTC)
            start_date = (now - datetime.timedelta(days=now.weekday())).replace(
                hour=0,
                minute=0,
                second=0,
                microsecond=0,
            )
        elif period == LeaderboardPeriod.monthly:
            # Start of current month
            start_date = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        elif period == LeaderboardPeriod.last_week:
            # Previous Monday to this Monday
            this_monday = (now - datetime.timedelta(days=now.weekday())).replace(
                hour=0,
                minute=0,
                second=0,
                microsecond=0,
            )
            start_date = this_monday - datetime.timedelta(days=7)
            end_date = this_monday
        elif period == LeaderboardPeriod.last_month:
            # Previous month 1st to current month 1st
            first_of_this_month = now.replace(
                day=1,
                hour=0,
                minute=0,
                second=0,
                microsecond=0,
            )
            # Go back to previous month
            if first_of_this_month.month == 1:
                start_date = first_of_this_month.replace(
                    year=first_of_this_month.year - 1,
                    month=12,
                )
            else:
                start_date = first_of_this_month.replace(
                    month=first_of_this_month.month - 1,
                )
            end_date = first_of_this_month
        # all_time: start_date and end_date remain None

        # Fetch leaderboard entries and total count
        entries = await self._db.survival_runs.get_leaderboard(
            limit=page_size,
            offset=offset,
            start_date=start_date,
            end_date=end_date,
        )
        total_count = await self._db.survival_runs.get_leaderboard_total_count(
            start_date=start_date,
            end_date=end_date,
        )
        total_pages = (total_count + page_size - 1) // page_size

        # Get current user's entry (may not be in current page)
        user_entry = await self._db.survival_runs.get_user_leaderboard_entry(
            user_firebase_uid=user_firebase_uid,
            start_date=start_date,
            end_date=end_date,
        )

        # Fetch percentiles for all users in leaderboard
        all_firebase_uids = [e['user_firebase_uid'] for e in entries]
        if user_entry and user_entry['user_firebase_uid'] not in all_firebase_uids:
            all_firebase_uids.append(user_entry['user_firebase_uid'])
        percentiles_map = await self._db.answers.get_overall_avg_percentiles_batch(
            all_firebase_uids,
        )

        return LeaderboardResponse(
            entries=[
                LeaderboardEntry(
                    rank=e['rank'],
                    display_name=e['display_name'],
                    picture=e['picture'],
                    rank_picture=get_rank_picture_for_percentile(
                        percentiles_map.get(e['user_firebase_uid'], 100),
                        request=request,
                    ),
                    best_streak=e['streak'],
                    is_completed=e['is_completed'],
                )
                for e in entries
            ],
            current_user=LeaderboardEntry(
                rank=user_entry['rank'],
                display_name=user_entry['display_name'],
                picture=user_entry['picture'],
                rank_picture=get_rank_picture_for_percentile(
                    percentiles_map.get(user_entry['user_firebase_uid'], 100),
                    request=request,
                ),
                best_streak=user_entry['streak'],
                is_completed=user_entry['is_completed'],
            )
            if user_entry
            else None,
            total_count=total_count,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
        )

    async def _get_random_question(self, user_firebase_uid: str) -> Fermi:
        """Fetch a random unseen question for the user."""
        questions = await self._db.fermi.get_unseen_random_questions(
            count=1,
            for_user_ids=[user_firebase_uid],
        )
        if not questions:
            raise ValueError('No questions available')
        return questions[0]

    async def _build_question_data(
        self,
        question: Fermi,
        user_firebase_uid: str,
    ) -> SurvivalQuestionData:
        """Build question data with units and vote info."""
        units = get_unit_family(question.unit) if question.unit else None
        upvotes = await self._db.question_votes.get_upvotes(question.uid)
        user_vote = await self._db.question_votes.get_player_vote_verdict(
            question.uid,
            user_firebase_uid=user_firebase_uid,
        )

        return SurvivalQuestionData(
            question_uid=str(question.uid),
            text=question.text,
            category=question.category,
            difficulty=question.difficulty,
            units=units,
            upvotes=upvotes,
            user_vote=user_vote,
            year=question.created_at.year,
        )

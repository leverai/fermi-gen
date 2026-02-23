"""Precision Rush service for gameplay logic."""

import datetime
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

from app.schemas.precision_rush import (
    PRAnswerResponse,
    PRLeaderboardEntry,
    PRLeaderboardResponse,
    PRQuestionData,
    PRQuestionResponse,
    PRRunSummary,
    PRStatsResponse,
)
from app.schemas.survival import LeaderboardPeriod
from app.services.game.ranks import get_rank_picture_for_percentile
from app.services.scoring import ScoringService

logger = logging.getLogger(__name__)

if TYPE_CHECKING:
    from fermi_db import DatabaseClient
    from fermi_db.models.precision_rush import PrecisionRushRun

    from app.schemas.game import ScoreQuantiles


# Constants
PR_TIME_LIMIT_SECONDS = 40
PR_TOTAL_QUESTIONS = 6
PR_GRACE_PERIOD_SECONDS = 20
PR_GRACE_PERIOD = timedelta(seconds=PR_GRACE_PERIOD_SECONDS)

# Free tier limit: 1 PR run per calendar day
FREE_PR_RUNS_PER_DAY = 1


class PrecisionRushService:
    """Service for Precision Rush gameplay logic."""

    def __init__(self, db_client: 'DatabaseClient') -> None:
        """Initialize the service with a database client."""
        self._db = db_client
        self._scoring = ScoringService()

    async def _get_active_run(self, run_id: int) -> 'PrecisionRushRun':
        """Get an active run by id."""
        run = await self._db.precision_rush_runs.get_run_by_id(run_id)
        if run is None:
            raise ValueError(f'Run {run_id} not found')
        if run.ended_at:
            raise ValueError(f'Run {run_id} already ended at {run.ended_at}')
        return run

    async def create_or_resume_run(
        self,
        user_firebase_uid: str,
        run_id: int | None = None,
        *,
        is_pro: bool = False,
    ) -> PRQuestionResponse:
        """Create a new PR run or resume an existing one.

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

        run: PrecisionRushRun | None = None
        if run_id:
            run = await self._get_active_run(run_id)
            span.set_attribute('pr.run_id', run_id)
        else:
            run = await self._db.precision_rush_runs.get_active_run(
                user_firebase_uid=user_firebase_uid,
            )

        question = await self._get_random_question(
            user_firebase_uid=user_firebase_uid,
        )
        deadline = utcnow_naive() + timedelta(seconds=PR_TIME_LIMIT_SECONDS)

        if run:
            run = await self._db.precision_rush_runs.set_current_question(
                run_id=run.id,
                question_uid=str(question.uid),
                deadline=deadline,
            )
        else:
            # Creating new run — check limits for free users
            if not is_pro:
                remaining = await self._db.precision_rush_runs.get_runs_remaining_today(
                    user_firebase_uid=user_firebase_uid,
                    limit=FREE_PR_RUNS_PER_DAY,
                )
                if remaining <= 0:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail='Daily Precision Rush run limit reached',
                    )

            run = await self._db.precision_rush_runs.create_run(
                user_firebase_uid=user_firebase_uid,
                question_uid=str(question.uid),
                deadline=deadline,
            )

        assert run.id, 'This should not happen.'
        question_data = await self._build_question_data(question, user_firebase_uid)
        return PRQuestionResponse(
            run_id=run.id,
            question_number=run.questions_answered + 1,
            total_questions=PR_TOTAL_QUESTIONS,
            question=question_data,
            total_tas=run.total_tas,
            time_limit_seconds=PR_TIME_LIMIT_SECONDS,
            answer_deadline_utc=deadline.isoformat() + 'Z',
        )

    async def submit_answer(
        self,
        user_firebase_uid: str,
        run_id: int,
        answer: AnswerBare,
    ) -> PRAnswerResponse:
        """Submit an answer for the current question.

        Compute accuracy score and TAS (time-accuracy score).
        TAS = accuracy_score * (1 + time_remaining / time_limit).
        """
        span = trace.get_current_span()
        span.set_attribute('pr.player_answer', str(answer))

        # 1. Get and validate run
        run = await self._db.precision_rush_runs.get_run_by_id(run_id)
        if run is None:
            raise ValueError(f'Run {run_id} not found')

        span.set_attribute('pr.run_id', run_id)
        span.set_attribute('pr.questions_answered', run.questions_answered)

        if run.user_firebase_uid != user_firebase_uid:
            raise ValueError('Run does not belong to user')
        if run.ended_at:
            raise ValueError('Run is already completed')

        # Validate deadline
        if run.current_deadline is None:
            raise ValueError('Run is not active')
        now = utcnow_naive()
        if now - PR_GRACE_PERIOD > run.current_deadline:
            raise ValueError('Run is past deadline')

        # 2. Get question, compute score and TAS
        correct_answer_w_snippet = await self._db.fermi.get_answer_with_snippet_by_uid(
            uuid.UUID(run.current_question_uid),
        )
        assert correct_answer_w_snippet, 'This should not happen.'
        correct_answer = AnswerBare(
            number=correct_answer_w_snippet['number'],
            unit=correct_answer_w_snippet['unit'],
        )
        span.set_attribute('pr.question_uid', str(run.current_question_uid))

        accuracy_score = self._scoring.calculate_score(answer, correct_answer)

        # Compute time bonus: 1.0 (at deadline) to 2.0 (instant)
        time_remaining = (run.current_deadline - now).total_seconds()
        time_remaining = max(0.0, time_remaining)
        time_bonus = 1.0 + (time_remaining / PR_TIME_LIMIT_SECONDS)
        tas = accuracy_score * time_bonus

        # Percentile
        quantiles = await self._db.answers.get_question_quantiles(
            uuid.UUID(run.current_question_uid),
        )
        quantiles_dict = cast(
            'ScoreQuantiles',
            quantiles.model_dump(exclude={'question_uid'}),
        )
        quantile = self._scoring.get_score_quantile(accuracy_score, quantiles_dict)

        span.set_attribute('pr.score', accuracy_score)
        span.set_attribute('pr.tas', tas)

        # 3. Update run record (auto-completes after 6)
        run = await self._db.precision_rush_runs.submit_score(run_id, tas)
        assert run.id, 'This should not happen.'

        # Convert correct answer to player's unit if applicable
        if answer['unit']:
            converted_answer = convert_answer_to_user_unit(
                player_unit_id=answer['unit'],
                correct_answer=correct_answer,
            )
        else:
            converted_answer = correct_answer

        # 4. Log answer event and history
        answer_event = AnswerEvent(
            question_uid=uuid.UUID(run.current_question_uid),
            question_difficulty=QuestionDifficulty.MEDIUM,
            question_category=QuestionCategory.OTHER,
            user_firebase_id=user_firebase_uid,
            game_id=str(run_id),
            answer=answer,
            correct_answer=converted_answer,
            score_number=accuracy_score,
            score_quantile=quantile,
            game_mode=GameMode.PRECISION_RUSH,
        )
        await self._db.answers.add_answers([answer_event])
        await self._db.users_history.add_questions_to_users_history(
            user_ids=[user_firebase_uid],
            question_uids=[run.current_question_uid],
        )

        # Increment XP
        xp_increment = int(accuracy_score // 100)
        if xp_increment > 0:
            await self._db.users.increment_xp(user_firebase_uid, xp_increment)

        is_final = run.questions_answered >= PR_TOTAL_QUESTIONS
        return PRAnswerResponse(
            score=accuracy_score,
            tas=tas,
            percentile=quantile * 100,
            correct_answer=correct_answer,
            converted_correct_answer=converted_answer,
            user_answer=answer,
            question_number=run.questions_answered,
            total_tas=run.total_tas,
            is_final=is_final,
            run_summary=PRRunSummary(
                run_id=run_id,
                questions_answered=run.questions_answered,
                total_tas=run.total_tas,
            )
            if is_final
            else None,
            ai_overview=correct_answer_w_snippet['ai_overview'],
        )

    async def get_stats(self, user_firebase_uid: str) -> PRStatsResponse:
        """Get user's Precision Rush statistics."""
        total_runs = await self._db.precision_rush_runs.count_user_runs(
            user_firebase_uid,
        )
        best_tas = await self._db.precision_rush_runs.get_user_best_tas(
            user_firebase_uid,
        )
        avg_tas = await self._db.precision_rush_runs.get_user_average_tas(
            user_firebase_uid,
        )
        active_run = await self._db.precision_rush_runs.get_active_run(
            user_firebase_uid,
        )
        return PRStatsResponse(
            total_runs=total_runs,
            best_tas=best_tas,
            average_tas=avg_tas,
            active_run_id=active_run.id if active_run else None,
            active_run_questions_answered=active_run.questions_answered
            if active_run
            else None,
        )

    async def get_leaderboard(
        self,
        user_firebase_uid: str,
        page: int = 1,
        page_size: int = 25,
        period: LeaderboardPeriod = LeaderboardPeriod.weekly,
        request: Request | None = None,
    ) -> PRLeaderboardResponse:
        """Get paginated global leaderboard ranked by best TAS."""
        offset = (page - 1) * page_size

        start_date, end_date = self._compute_date_range(period)

        entries = await self._db.precision_rush_runs.get_leaderboard(
            limit=page_size,
            offset=offset,
            start_date=start_date,
            end_date=end_date,
        )
        total_count = await self._db.precision_rush_runs.get_leaderboard_total_count(
            start_date=start_date,
            end_date=end_date,
        )
        total_pages = (total_count + page_size - 1) // page_size

        user_entry = await self._db.precision_rush_runs.get_user_leaderboard_entry(
            user_firebase_uid=user_firebase_uid,
            start_date=start_date,
            end_date=end_date,
        )

        # Fetch rank pictures
        all_firebase_uids = [e['user_firebase_uid'] for e in entries]
        if user_entry and user_entry['user_firebase_uid'] not in all_firebase_uids:
            all_firebase_uids.append(user_entry['user_firebase_uid'])
        percentiles_map = await self._db.answers.get_overall_avg_percentiles_batch(
            all_firebase_uids,
        )

        return PRLeaderboardResponse(
            entries=[
                PRLeaderboardEntry(
                    rank=e['rank'],
                    display_name=e['display_name'],
                    picture=e['picture'],
                    rank_picture=get_rank_picture_for_percentile(
                        percentiles_map.get(e['user_firebase_uid'], 100),
                        request=request,
                    ),
                    best_tas=e['best_tas'],
                )
                for e in entries
            ],
            current_user=PRLeaderboardEntry(
                rank=user_entry['rank'],
                display_name=user_entry['display_name'],
                picture=user_entry['picture'],
                rank_picture=get_rank_picture_for_percentile(
                    percentiles_map.get(user_entry['user_firebase_uid'], 100),
                    request=request,
                ),
                best_tas=user_entry['best_tas'],
            )
            if user_entry
            else None,
            total_count=total_count,
            page=page,
            page_size=page_size,
            total_pages=total_pages,
        )

    # --- Private helpers ---

    @staticmethod
    def _compute_date_range(
        period: LeaderboardPeriod,
    ) -> tuple[datetime.datetime | None, datetime.datetime | None]:
        """Compute (start_date, end_date) for a leaderboard period."""
        now = datetime.datetime.now(datetime.UTC).replace(tzinfo=None)
        start_date: datetime.datetime | None = None
        end_date: datetime.datetime | None = None

        if period == LeaderboardPeriod.weekly:
            start_date = (now - datetime.timedelta(days=now.weekday())).replace(
                hour=0,
                minute=0,
                second=0,
                microsecond=0,
            )
        elif period == LeaderboardPeriod.monthly:
            start_date = now.replace(day=1, hour=0, minute=0, second=0, microsecond=0)
        elif period == LeaderboardPeriod.last_week:
            this_monday = (now - datetime.timedelta(days=now.weekday())).replace(
                hour=0,
                minute=0,
                second=0,
                microsecond=0,
            )
            start_date = this_monday - datetime.timedelta(days=7)
            end_date = this_monday
        elif period == LeaderboardPeriod.last_month:
            first_of_this_month = now.replace(
                day=1,
                hour=0,
                minute=0,
                second=0,
                microsecond=0,
            )
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

        return start_date, end_date

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
    ) -> PRQuestionData:
        """Build question data with units and vote info."""
        units = get_unit_family(question.unit) if question.unit else None
        upvotes = await self._db.question_votes.get_upvotes(question.uid)
        user_vote = await self._db.question_votes.get_player_vote_verdict(
            question.uid,
            user_firebase_uid=user_firebase_uid,
        )

        return PRQuestionData(
            question_uid=str(question.uid),
            text=question.text,
            category=question.category,
            difficulty=question.difficulty,
            units=units,
            upvotes=upvotes,
            user_vote=user_vote,
            year=question.created_at.year,
        )

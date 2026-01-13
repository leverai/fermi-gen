"""Survival Mode service for gameplay logic."""

import logging
import uuid
from datetime import timedelta
from typing import TYPE_CHECKING, cast

from fermi_core.units import convert_answer_to_user_unit, get_unit_family
from fermi_core.utils import utcnow_naive
from fermi_db.models import AnswerEvent, Fermi
from fermi_db.schemas import AnswerBare, QuestionCategory, QuestionDifficulty
from opentelemetry import trace

import app.logging.attributes as attrs
from app.schemas import (
    StreakInfo,
    SurvivalAnswerResponse,
    SurvivalQuestionData,
    SurvivalQuestionResponse,
    SurvivalRunSummary,
    SurvivalStatsResponse,
)
from app.services.scoring import ScoringService

logger = logging.getLogger(__name__)

if TYPE_CHECKING:
    from fermi_db import DatabaseClient
    from fermi_db.models.survival import SurvivalRun

    from app.schemas.game import ScoreQuantiles


# Constants
SURVIVAL_TIME_LIMIT_SECONDS = 40
GRACE_PERIOD_SECONDS = 20
GRACE_PERIOD = timedelta(seconds=GRACE_PERIOD_SECONDS)


class SurvivalService:
    """Service for survival mode gameplay logic."""

    def __init__(self, db_client: 'DatabaseClient') -> None:
        """Initialize the service with a database client."""
        self._db = db_client
        self._scoring = ScoringService()

    async def _get_active_run(self, run_id: int) -> SurvivalRun:
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
    ) -> SurvivalQuestionResponse:
        """Step the run by one question."""
        span = trace.get_current_span()
        span.set_attribute(attrs.SURVIVAL_USER_ID, user_firebase_uid)

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
            # Create new run with the new question
            run = await self._db.survival_runs.create_run(
                user_firebase_uid=user_firebase_uid,
                question_uid=str(question.uid),
                deadline=deadline,
            )

        # We have a run now with the new question. Time to return to user
        assert run.id, 'This should not happen.'
        question_data = await self._build_question_data(question, user_firebase_uid)
        return SurvivalQuestionResponse(
            run_id=run.id,
            question_number=run.questions_answered + 1,
            question=question_data,
            time_limit_seconds=SURVIVAL_TIME_LIMIT_SECONDS,
            answer_deadline_utc=deadline.isoformat() + 'Z',
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
        if correct_answer is None:
            raise ValueError(f'Question {run.current_question_uid} not found')
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

        # 4. Update answer events and user history
        answer_event = AnswerEvent(
            question_uid=uuid.UUID(run.current_question_uid),
            # TODO: remove cat and diff from AnswerEvent
            question_difficulty=QuestionDifficulty.MEDIUM,
            question_category=QuestionCategory.OTHER,
            user_firebase_id=user_firebase_uid,
            game_id=str(run_id),
            answer=answer,
            correct_answer=correct_answer,
            score_number=score,
            score_quantile=quantile,
        )
        await self._db.answers.add_answers([answer_event])
        await self._db.users_history.add_questions_to_users_history(
            user_ids=[user_firebase_uid],
            question_uids=[run.current_question_uid],
        )

        # Increment XP
        xp_increment = int(score // 100)
        if xp_increment > 0:
            await self._db.users.increment_xp(user_firebase_uid, xp_increment)

        # Convert correct answer to player's unit if applicable
        if answer['unit']:
            converted_answer = convert_answer_to_user_unit(
                player_unit_id=answer['unit'],
                correct_answer=correct_answer,
            )
        else:
            converted_answer = correct_answer

        streak = run.questions_answered if passed else run.questions_answered - 1
        return SurvivalAnswerResponse(
            passed=passed,
            score=score,
            percentile=quantile * 100,
            pass_threshold=pass_threshold,
            correct_answer=correct_answer,
            converted_correct_answer=converted_answer,
            user_answer=answer,
            total_questions=run.questions_answered,
            total_score=run.total_score,
            run_summary=SurvivalRunSummary(
                run_id=run_id,
                questions_answered=streak,
                total_score=run.total_score,
            ),
            ai_overview=correct_answer_w_snippet['ai_overview'],
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
        best_streak = (best_run.questions_answered - 1) if best_run else 0

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
        )

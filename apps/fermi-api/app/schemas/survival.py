"""Pydantic schemas for Survival Mode endpoints."""

from typing import TypedDict

from fermi_core.schemas.units import UnitInfo
from fermi_core.units import Locale
from fermi_db.models.game import VoteVerdict
from fermi_db.schemas import AnswerBare, QuestionCategory, QuestionDifficulty
from pydantic import BaseModel


class SurvivalQuestionData(BaseModel):
    """Question data returned for survival mode."""

    question_uid: str
    text: str
    category: QuestionCategory | None
    difficulty: QuestionDifficulty | None
    units: dict[Locale, list[UnitInfo]] | None = None
    upvotes: int
    user_vote: VoteVerdict


class SurvivalQuestionResponse(BaseModel):
    """Response for starting/continuing survival."""

    run_id: int
    question_number: int
    question: SurvivalQuestionData
    time_limit_seconds: int  # Always 40
    answer_deadline_utc: str  # ISO timestamp


class CreateOrResumeRequest(BaseModel):
    """Request for the create or resume request."""

    run_id: int | None = None


class SurvivalAnswerRequest(BaseModel):
    """Request for submitting a survival answer."""

    run_id: int
    answer: AnswerBare


class SurvivalRunSummary(BaseModel):
    """Summary of a completed survival run."""

    run_id: int
    questions_answered: int
    total_score: float


class SurvivalAnswerResponse(BaseModel):
    """Response for answer submission."""

    passed: bool
    score: float
    percentile: float
    pass_threshold: float  # The p50 score they needed to beat
    correct_answer: AnswerBare
    converted_correct_answer: AnswerBare  # In player's unit
    user_answer: AnswerBare
    total_questions: int  # Questions answered so far
    total_score: float  # Cumulative score
    run_summary: SurvivalRunSummary | None = None
    ai_overview: str | None = None


class SurvivalStatsResponse(BaseModel):
    """User's survival mode statistics."""

    total_runs: int
    best_streak: int  # Most questions answered in one run
    average_streak: float
    total_questions_answered: int


class StreakInfo(TypedDict):
    """User's streak stats."""

    best_streak: int
    current_streak: int

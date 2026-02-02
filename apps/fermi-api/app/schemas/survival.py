"""Pydantic schemas for Survival Mode endpoints."""

from fermi_core.schemas.units import UnitInfo
from fermi_core.units import Locale
from fermi_db.models.game import VoteVerdict
from fermi_db.schemas import AnswerBare, QuestionCategory, QuestionDifficulty
from pydantic import BaseModel
from typing_extensions import TypedDict


class SurvivalQuestionData(BaseModel):
    """Question data returned for survival mode."""

    question_uid: str
    text: str
    category: QuestionCategory | None
    difficulty: QuestionDifficulty | None
    units: dict[Locale, list[UnitInfo]] | None = None
    upvotes: int
    user_vote: VoteVerdict
    year: int


class SurvivalQuestionResponse(BaseModel):
    """Response for starting/continuing survival."""

    run_id: int
    question_number: int
    question: SurvivalQuestionData
    time_limit_seconds: int  # Always 40
    answer_deadline_utc: str  # ISO timestamp
    streak: int  # Current streak (accounts for ad saves)
    can_use_ad_save: bool  # Whether player can use ad save this run


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
    streak: int  # Correct consecutive answers (accounts for ad saves)
    total_score: float


class SurvivalAnswerResponse(BaseModel):
    """Response for answer submission."""

    passed: bool
    score: float
    percentile: float
    pass_threshold: float  # The p50 score they needed to beat
    p50_ratio: (
        float  # Ratio for acceptable answer bounds: [correct/ratio, correct*ratio]
    )
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


class LeaderboardEntry(BaseModel):
    """Single entry in the survival leaderboard."""

    rank: int
    display_name: str | None
    picture: str | None
    rank_picture: str | None = None
    best_streak: int
    is_completed: bool  # Whether their best run has ended


class LeaderboardResponse(BaseModel):
    """Paginated leaderboard response."""

    entries: list[LeaderboardEntry]
    current_user: LeaderboardEntry | None  # Always included if user has played
    total_count: int
    page: int
    page_size: int
    total_pages: int


class ContinueWithAdRequest(BaseModel):
    """Request for continuing a survival run after watching an ad."""

    run_id: int


class ContinueWithAdResponse(BaseModel):
    """Response after successfully continuing with an ad."""

    run_id: int
    question_number: int
    question: SurvivalQuestionData
    time_limit_seconds: int
    answer_deadline_utc: str
    streak: int  # Current streak (preserved by ad save)
    can_use_ad_save: bool  # Always False after using ad save

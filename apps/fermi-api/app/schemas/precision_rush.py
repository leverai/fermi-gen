"""Pydantic schemas for Precision Rush endpoints."""

from fermi_core.schemas.units import UnitInfo
from fermi_core.units import Locale
from fermi_db.models.game import VoteVerdict
from fermi_db.schemas import AnswerBare, QuestionCategory, QuestionDifficulty
from pydantic import BaseModel


class PRQuestionData(BaseModel):
    """Question data returned for Precision Rush mode."""

    question_uid: str
    text: str
    category: QuestionCategory | None
    difficulty: QuestionDifficulty | None
    units: dict[Locale, list[UnitInfo]] | None = None
    upvotes: int
    user_vote: VoteVerdict
    year: int


class PRQuestionResponse(BaseModel):
    """Response for starting/continuing a PR run."""

    run_id: int
    question_number: int
    total_questions: int  # Always 6
    question: PRQuestionData
    time_limit_seconds: int  # Always 40
    answer_deadline_utc: str  # ISO timestamp


class PRAnswerRequest(BaseModel):
    """Request for submitting a PR answer."""

    run_id: int
    answer: AnswerBare


class PRRunSummary(BaseModel):
    """Summary of a completed PR run."""

    run_id: int
    questions_answered: int
    total_tas: float


class PRAnswerResponse(BaseModel):
    """Response for answer submission."""

    score: float  # Accuracy score
    tas: float  # Time-accuracy score for this question
    percentile: float
    correct_answer: AnswerBare
    converted_correct_answer: AnswerBare  # In player's unit
    user_answer: AnswerBare
    question_number: int
    total_tas: float  # Cumulative TAS so far
    is_final: bool  # True if this was the 6th question
    run_summary: PRRunSummary | None = None
    ai_overview: str | None = None


class PRStatsResponse(BaseModel):
    """User's Precision Rush statistics."""

    total_runs: int
    best_tas: float
    average_tas: float
    active_run_id: int | None = None
    active_run_questions_answered: int | None = None


class PRLeaderboardEntry(BaseModel):
    """Single entry in the PR leaderboard."""

    rank: int
    display_name: str | None
    picture: str | None
    rank_picture: str | None = None
    best_tas: float


class PRLeaderboardResponse(BaseModel):
    """Paginated leaderboard response."""

    entries: list[PRLeaderboardEntry]
    current_user: PRLeaderboardEntry | None
    total_count: int
    page: int
    page_size: int
    total_pages: int

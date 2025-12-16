"""Pydantic schemas for Daily Question endpoints."""

from datetime import datetime
from enum import StrEnum

from fermi_db.schemas import AnswerBare, QuestionCategory, QuestionDifficulty
from pydantic import BaseModel


class DQWindowStatus(StrEnum):
    """Status of the daily question window."""

    NOT_STARTED = 'NOT_STARTED'  # Before 8 AM
    ACTIVE = 'ACTIVE'  # 8 AM - 8 PM
    CLOSED = 'CLOSED'  # After 8 PM


class DQUserStatus(StrEnum):
    """User's status for the current daily question."""

    NOT_STARTED = 'NOT_STARTED'  # User hasn't started yet
    IN_PROGRESS = 'IN_PROGRESS'  # User is answering
    SUBMITTED = 'SUBMITTED'  # User has submitted
    MISSED = 'MISSED'  # Window closed, user didn't answer


class DQStatusResponse(BaseModel):
    """Response for GET /daily_question/status."""

    window_status: DQWindowStatus
    seconds_until_window_end: float | None = None
    question_date: str | None = None  # YYYY-MM-DD format
    user_status: DQUserStatus | None = None
    has_results: bool = False


class DQQuestionData(BaseModel):
    """Question data returned when starting DQ."""

    question_uid: str
    text: str
    category: QuestionCategory | None
    difficulty: QuestionDifficulty | None
    unit_hint: str | None = None  # Suggested unit if applicable


class DQQuestionResponse(BaseModel):
    """Response for POST /daily_question/start."""

    question: DQQuestionData
    answer_deadline_utc: str  # ISO format timestamp
    seconds_to_answer: float


class DQAnswerRequest(BaseModel):
    """Request for POST /daily_question/answer."""

    answer: AnswerBare


class DQSubmitResponse(BaseModel):
    """Response for POST /daily_question/answer."""

    submitted: bool
    score: float | None = None
    message: str | None = None


class DQLeaderboardEntry(BaseModel):
    """A single entry in the leaderboard."""

    rank: int
    display_name: str | None
    score: float
    time_taken_s: float


class DQResultsResponse(BaseModel):
    """Response for GET /daily_question/results."""

    question_date: str  # YYYY-MM-DD
    question_uid: str
    question_text: str
    correct_answer: AnswerBare
    user_answer: AnswerBare | None
    user_score: float | None
    user_rank: int | None
    total_participants: int
    leaderboard: list[DQLeaderboardEntry]


class DQHistoryItem(BaseModel):
    """A single item in the user's DQ history."""

    question_date: str  # YYYY-MM-DD
    question_text: str
    user_answer: AnswerBare
    correct_answer: AnswerBare
    score: float
    rank: int | None
    total_participants: int


class DQHistoryResponse(BaseModel):
    """Response for GET /daily_question/history."""

    history: list[DQHistoryItem]


class DQUserSession(BaseModel):
    """User session data from Firestore.

    Used to parse and validate session documents retrieved from Firestore.
    Pydantic automatically converts ISO 8601 strings to datetime objects.
    """

    started_at: datetime
    answer_deadline: datetime
    submitted: bool

"""Pydantic schemas for Daily Question endpoints."""

from datetime import datetime
from enum import StrEnum
from typing import TypedDict

from fermi_core.schemas.units import UnitInfo
from fermi_db.schemas import AnswerBare, QuestionCategory, QuestionDifficulty
from pydantic import BaseModel


class DQWindowStatus(StrEnum):
    """Status of the daily question window.

    Timing (all in UTC):
    - NOT_STARTED: 2AM UTC to 12PM UTC (same day)
    - ACTIVE: 12PM UTC to 2AM UTC (next day)
    - CLOSED: After 2AM UTC (next day)
    """

    NOT_STARTED = 'NOT_STARTED'
    ACTIVE = 'ACTIVE'
    CLOSED = 'CLOSED'


class DQQuestionData(BaseModel):
    """Question data returned when starting DQ."""

    question_uid: str
    text: str
    category: QuestionCategory | None
    difficulty: QuestionDifficulty | None
    units: dict[str, list[UnitInfo]] | None = (
        None  # Unit family: {US: [...], EU: [...]}
    )


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


class DQLiteArchiveResponse(BaseModel):
    """Response for GET /daily_question/archive/week and /archive/month.

    Provides a lightweight archive for the DQ carousel and calendar views.
    Frontend uses this to show past DQs and whether the user participated.
    """

    items: dict[str, bool]  # {date_str (YYYY-MM-DD): user_participated}
    today: str  # The current DQ date the frontend should subscribe to


class DQUserSession(TypedDict):
    """User session data from Firestore."""

    started_at: datetime
    answer_deadline: datetime
    submitted: bool


class DqDoc(TypedDict):
    """Daily question document data from Firestore.

    The frontend subscribes to this document for real-time status updates.
    """

    question_uid: str
    status: DQWindowStatus
    window_start: datetime
    window_end: datetime
    results_ready: bool


class DQEndResponse(BaseModel):
    """Response for POST /daily_question/end/{date}."""

    closed_date: str  # YYYY-MM-DD
    participants_ranked: int
    next_date: str | None = None  # YYYY-MM-DD, None if no questions available
    next_question_uid: str | None = None

"""Pydantic models for DeathMatch Firestore documents."""

from enum import IntEnum
from typing import NotRequired

from fermi_core.schemas.units import UnitInfo
from fermi_core.units import Locale
from fermi_db.schemas import AnswerBare, QuestionCategory, QuestionDifficulty
from pydantic import BaseModel
from typing_extensions import TypedDict


class DMState(IntEnum):
    """DeathMatch match state."""

    WAITING_FOR_OPPONENT = 0
    QUESTION_ACTIVE = 1
    QUESTION_RESOLVED = 2
    MATCH_FINISHED = 3


class DMPlayer(TypedDict):
    """Player info stored in the match document."""

    player_id: str
    name: str | None
    picture: str | None
    points: int


class DMMatchDoc(TypedDict):
    """Top-level DeathMatch match document in Firestore."""

    state: int
    player1: DMPlayer
    player2: DMPlayer | None
    question_uid: str | None
    question_text: str | None
    question_category: NotRequired[str | None]
    question_difficulty: NotRequired[str | None]
    question_units: NotRequired[dict[Locale, list[UnitInfo]] | None]
    question_year: NotRequired[int]
    question_upvotes: NotRequired[int]
    answer_number: NotRequired[float]
    answer_unit: NotRequired[str | None]
    answer_paragraph: NotRequired[str]
    answer_quantiles: NotRequired[dict]
    player1_answered: bool
    player2_answered: bool
    player1_answer: NotRequired[AnswerBare]
    player2_answer: NotRequired[AnswerBare]
    player1_score: NotRequired[float]
    player2_score: NotRequired[float]
    winner: str | None
    points_transferred: int
    created_at: object | None


# ---------- Endpoint request / response models ----------

POINTS_STAKE = 50


class DMQuestionData(BaseModel):
    """Question data sent to DeathMatch players."""

    question_uid: str
    text: str
    category: QuestionCategory | None = None
    difficulty: QuestionDifficulty | None = None
    units: dict[Locale, list[UnitInfo]] | None = None
    upvotes: int = 0
    year: int = 0


class DMQueueResponse(BaseModel):
    """Response when a player enters the matchmaking queue."""

    match_id: str
    status: str  # 'waiting' or 'matched'


class DMMatchStatusResponse(BaseModel):
    """Current match status (polled or listened to via Firestore)."""

    match_id: str
    state: DMState
    player1: DMPlayer
    player2: DMPlayer | None = None
    question: DMQuestionData | None = None
    your_answered: bool = False
    opponent_answered: bool = False


class DMAnswerRequest(BaseModel):
    """Request body for submitting an answer."""

    match_id: str
    answer: AnswerBare


class DMAnswerResponse(BaseModel):
    """Response after submitting an answer."""

    match_id: str
    waiting_for_opponent: bool


class DMResultResponse(BaseModel):
    """Result after both players answered."""

    match_id: str
    winner: str | None
    your_score: float
    opponent_score: float
    your_answer: AnswerBare
    opponent_answer: AnswerBare
    correct_answer: AnswerBare
    points_transferred: int
    your_new_points: int


class DMLeaveResponse(BaseModel):
    """Response when leaving / forfeiting."""

    match_id: str
    forfeited: bool

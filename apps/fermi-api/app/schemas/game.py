"""Pydantic models for game-doc-related fields and subcollections."""

from enum import IntEnum
from typing import TYPE_CHECKING, NotRequired, Optional

from fermi_db.schemas import (
    AnswerBare,
    Locale,
    QuestionCategory,
    QuestionDifficulty,
)
from typing_extensions import TypedDict

from app.schemas.endpoints import RequestCategory, RequestDifficulty

if TYPE_CHECKING:
    from fermi_db.models.game import VoteVerdict
    from google.cloud.firestore_v1.transforms import Sentinel


class GamePlayer(TypedDict):
    """Game player info."""

    player_id: str
    name: str | None
    picture: str | None
    score: float
    rank: int
    is_host: bool
    is_active: bool


class AnswersProgress(TypedDict):
    """Answers progress for a question."""

    answered: dict[str, bool]
    all_answered: bool


class GameState(IntEnum):
    """Game state."""

    PRE_LOBBY = 0
    LOBBY_NOT_READY = 1
    LOBBY_READY = 2
    QUESTION_N = 3
    QUESTION_N_FINISHED = 4
    QUESTION_LAST = 5
    QUESTION_LAST_FINISHED = 6
    GAME_FINISHED = 8
    GAME_ABORTED = 9


class GameDocLifecycle(TypedDict):
    """Game document lifecycle fields."""

    id: str
    created_at: Optional['Sentinel']
    started_at: NotRequired['Sentinel']
    ended_at: NotRequired['Sentinel']
    state: str


class GameDocQuestions(TypedDict):
    """Game document questions fields."""

    n_questions: int
    category: RequestCategory | None
    difficulty: RequestDifficulty
    question_uids: list[str]
    question_uid: str
    question_number: int


class GameDocPlayers(TypedDict):
    """Game document players fields."""

    host: str
    players: dict[str, GamePlayer]
    full: bool
    max_players: int


class GameDocPlayersAnswers(TypedDict):
    """Game document players answers fields."""

    progress: AnswersProgress


class GameDoc(
    GameDocLifecycle,
    GameDocQuestions,
    GameDocPlayers,
    GameDocPlayersAnswers,
):
    """Game document."""

    join_url: str


class UnitInfo(TypedDict):
    """Information about a unit."""

    id: str
    name: str
    abbreviation: str


class Score(TypedDict):
    """Scored answer."""

    number: float
    quantile: float


class ScoreQuantiles(TypedDict):
    """Quantiles sub-collection."""

    p01: float
    p05: float
    p10: float
    p25: float
    p50: float
    p60: float
    p75: float
    p80: float
    p85: float
    p90: float
    p95: float
    p99: float


class AnswerDoc(TypedDict):
    """Answer sub-collection."""

    number: float
    unit: str | None
    quantiles: ScoreQuantiles
    paragraph: str
    revealed: bool


class QuestionDoc(TypedDict):
    """Game's version of a Fermi question."""

    question_uid: str
    text: str
    difficulty: QuestionDifficulty | None
    category: QuestionCategory | None
    year: int
    order: int
    units: dict[Locale, list[UnitInfo]] | None
    upvotes: int
    revealed: bool
    players_votes: dict[str, 'VoteVerdict']


class PlayerResult(TypedDict):
    """Player result."""

    answer: AnswerBare
    correct_answer: AnswerBare
    score: Score
    converted_answers: NotRequired[dict[str, AnswerBare]]


class PlayersResultsDoc(TypedDict):
    """Players results for a question."""

    question_uid: str
    players_results: dict[str, PlayerResult]
    revealed: bool

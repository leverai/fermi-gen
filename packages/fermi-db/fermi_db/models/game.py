"""Game-related DB models."""

import datetime
import uuid
from enum import IntEnum
from typing import Any

import sqlalchemy as sa
from fermi_core.utils import utcnow_naive
from pgvector.sqlalchemy import Vector
from sqlmodel import Field, SQLModel

from fermi_db.schemas import (
    AnswerBare,
    GameMode,
    QuestionCategory,
    QuestionDifficulty,
    QuestionStatus,
)

# In PostgreSQL, a standard integer is 4 bytes, with a max value of 2,147,483,647
MAX_INT = 2_147_483_647


class Fermi(SQLModel, table=True):
    """Table combining questions and answers for game selection.

    This was converted from a materialized view to a normal table to support
    human-in-the-loop question review via the status field.

    The uid is generated deterministically using uuid_generate_v5() based on
    fermi_questions.id, ensuring it remains stable. This allows backend tables
    (answer_events, questions_votes, user_question_history) to safely reference
    fermi.uid.
    """

    __tablename__ = 'fermi'  # type: ignore
    uid: uuid.UUID = Field(primary_key=True)
    question_id: int
    text: str
    question_source: dict[str, Any] = Field(sa_column=sa.Column(sa.JSON))
    answer_id: int
    number: float
    unit: str | None
    snippet: str
    used_ai_overview: bool
    difficulty: QuestionDifficulty | None
    category: QuestionCategory | None
    # Semantic embedding (backfilled from fermi_questions). Nullable: rows enriched
    # before this column existed, or not yet backfilled, have NULL. Used by smart
    # search (cosine distance). Mirrors the Vector(1536) used on fermi_questions.
    embedding: list[float] | None = Field(
        default=None,
        sa_column=sa.Column(Vector(1536)),
    )
    random_sort_key: int = Field(index=True)
    created_at: datetime.datetime = Field(
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )
    updated_at: datetime.datetime = Field(
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )
    # Human review status - only APPROVED questions are served to players
    status: QuestionStatus = Field(
        default=QuestionStatus.PENDING_REVIEW,
        index=True,
    )
    # Daily Question mode flag - True for questions reserved for DQ mode
    is_daily_question: bool = Field(default=False, index=True)
    # LLM answers for bot players
    gpt_5_1_number: float
    gpt_5_1_unit: str | None
    gpt_5_mini_number: float
    gpt_5_mini_unit: str | None
    gpt_5_nano_number: float
    gpt_5_nano_unit: str | None
    # Gemini Flash answers (high temperature, for casual/dumb bots)
    gemini_flash_1_number: float
    gemini_flash_1_unit: str | None
    gemini_flash_2_number: float
    gemini_flash_2_unit: str | None
    gemini_flash_3_number: float
    gemini_flash_3_unit: str | None
    gemini_flash_4_number: float
    gemini_flash_4_unit: str | None
    gemini_flash_5_number: float
    gemini_flash_5_unit: str | None


class UserQuestionHistory(SQLModel, table=True):
    """Records which user has seen which question.

    Note: question_uid references fermi.uid, but fermi is a materialized view
    so no FK constraint is enforced at the DB level. The uid is deterministic
    based on fermi_questions.id, ensuring stability across MV refreshes.
    """

    __tablename__ = 'user_question_history'  # type: ignore

    id: int | None = Field(default=None, primary_key=True)
    user_id: str = Field(index=True)
    question_uid: uuid.UUID = Field(index=True)
    seen_at: datetime.datetime | None = Field(
        default=None,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )


class AnswerEvent(SQLModel, table=True):
    """Represents a single answer event from a user.

    Note: question_uid references fermi.uid, but fermi is a materialized view
    so no FK constraint is enforced at the DB level. The uid is deterministic
    based on fermi_questions.id, ensuring stability across MV refreshes.
    """

    __tablename__ = 'answer_events'  # type: ignore
    uid: uuid.UUID = Field(default_factory=uuid.uuid4, primary_key=True)
    question_uid: uuid.UUID
    question_difficulty: QuestionDifficulty
    question_category: QuestionCategory
    user_firebase_id: str = Field(index=True)
    game_id: str
    answer: AnswerBare = Field(sa_column=sa.Column(sa.JSON))
    correct_answer: AnswerBare = Field(sa_column=sa.Column(sa.JSON))
    score_number: float
    score_quantile: float
    game_mode: GameMode | None = Field(default=None, index=True)
    created_at: datetime.datetime = Field(
        default_factory=utcnow_naive,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )


class AnswersQuantiles(SQLModel):
    """Score quantiles computed live from answer_events."""

    question_uid: uuid.UUID
    p01: float = 0.0
    p05: float = 0.0
    p10: float = 0.0
    p25: float = 0.0
    p50: float = 0.0
    p60: float = 0.0
    p75: float = 0.0
    p80: float = 0.0
    p85: float = 0.0
    p90: float = 0.0
    p95: float = 0.0
    p99: float = 0.0

    @staticmethod
    def easy(question_uid: uuid.UUID) -> 'AnswersQuantiles':
        """Return easy quantiles for cold-start protection (linear 1-1000)."""
        return AnswersQuantiles(
            question_uid=question_uid,
            p01=10.0,
            p05=50.0,
            p10=100.0,
            p25=250.0,
            p50=500.0,
            p60=600.0,
            p75=750.0,
            p80=800.0,
            p85=850.0,
            p90=900.0,
            p95=950.0,
            p99=990.0,
        )


class VoteVerdict(IntEnum):
    """Verdict of a user's vote on a question.

    Values are constrained to -1 (downvote), 0 (no vote), and 1 (upvote).
    """

    DOWNVOTE = -1
    NO_VOTE = 0
    UPVOTE = 1


class QuestionVote(SQLModel, table=True):
    """Tracks a user's vote on a specific question.

    The pair (question_uid, user_firebase_uid) is unique to ensure only one
    row per user/question.

    Note: question_uid references fermi.uid, but fermi is a materialized view
    so no FK constraint is enforced at the DB level. The uid is deterministic
    based on fermi_questions.id, ensuring stability across MV refreshes.
    """

    __tablename__ = 'questions_votes'  # type: ignore

    question_uid: uuid.UUID = Field(primary_key=True)
    user_firebase_uid: str = Field(primary_key=True)
    verdict: int = Field(
        default=VoteVerdict.NO_VOTE.value,
    )
    created_at: datetime.datetime = Field(
        default_factory=utcnow_naive,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )
    updated_at: datetime.datetime = Field(
        default_factory=utcnow_naive,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )


class PartyGameHosting(SQLModel, table=True):
    """Records party game hosting events for rate limiting.

    Used to track how many party games a user hosts per week for
    enforcing free tier limits (2/week).
    """

    __tablename__ = 'party_hostings'  # type: ignore

    id: int | None = Field(default=None, primary_key=True)
    user_id: int = Field(index=True, foreign_key='user.id')
    game_id: str = Field(max_length=255)
    created_at: datetime.datetime = Field(
        default_factory=utcnow_naive,
        index=True,
    )


class SmartSearchEvent(SQLModel, table=True):
    """Telemetry for a single smart-search game-start attempt.

    Records what a host searched for and what the similarity-gated pool returned,
    so the similarity floor and candidate-pool size can be tuned from real traffic.
    ``returned_similarities`` (cosine similarity = ``1 - distance``, parallel to
    ``returned_uids``) is the signal that drives floor tuning. Joinable to
    ``answer_events`` (via ``game_id``) for downstream relevance evaluation.

    ``game_id`` is nullable: a search that yields too few matches (or whose embed
    call failed) never creates a game, but is still recorded for tuning.
    """

    __tablename__ = 'smart_search_events'  # type: ignore

    id: int | None = Field(default=None, primary_key=True)
    user_id: str = Field(index=True)
    # Null when the search produced no game (too_few / embed_error).
    game_id: str | None = Field(default=None, index=True)
    query: str
    difficulty: QuestionDifficulty | None = None
    # uids of the questions served (as strings), parallel to returned_similarities.
    # Stored as str, not uuid.UUID: the column is a JSON array and the engine's
    # default json.dumps cannot serialize uuid.UUID (it raises and poisons the
    # session). Callers pass [str(uid) for ...]; see GameAnalyticsGateway.
    returned_uids: list[str] = Field(
        default_factory=list,
        sa_column=sa.Column(sa.JSON),
    )
    n: int
    # Cosine similarity (1 - distance) per returned question; tunes the floor.
    returned_similarities: list[float] = Field(
        default_factory=list,
        sa_column=sa.Column(sa.JSON),
    )
    # 'ok' | 'too_few' | 'embed_error'.
    outcome: str
    # The dials in effect for this row, so historical data stays interpretable.
    floor_used: float
    pool_size_used: int
    created_at: datetime.datetime = Field(
        default_factory=utcnow_naive,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )

"""Game-related DB models."""

import datetime
import uuid
from enum import IntEnum
from typing import Any

import sqlalchemy as sa
from fermi_core.utils import utcnow_naive
from sqlmodel import Field, SQLModel

from fermi_db.schemas import (
    AnswerBare,
    QuestionCategory,
    QuestionDifficulty,
)

# In PostgreSQL, a standard integer is 4 bytes, with a max value of 2,147,483,647
MAX_INT = 2_147_483_647


class Fermi(SQLModel, table=False):
    """Materialized view combining questions and answers for game selection.

    The uid is generated deterministically using uuid_generate_v5() based on
    fermi_questions.id, ensuring it remains stable across materialized view
    refreshes. This allows backend tables (answer_events, questions_votes,
    user_question_history) to safely reference fermi.uid.
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
    random_sort_key: int = Field(index=True)
    created_at: datetime.datetime = Field(
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )
    updated_at: datetime.datetime = Field(
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )


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

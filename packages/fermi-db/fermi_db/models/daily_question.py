"""Daily Question mode models."""

import datetime
import uuid

import sqlalchemy as sa
from fermi_core.utils import utcnow_naive
from sqlmodel import Field, SQLModel

from fermi_db.schemas import DailyQuestionStatus


class DailyQuestion(SQLModel, table=True):
    """Tracks a daily question for a specific date.

    All timestamps are stored in UTC. The API layer converts to/from
    Central time for display purposes.
    """

    __tablename__ = 'daily_questions'  # type: ignore

    id: int | None = Field(default=None, primary_key=True)
    question_date: datetime.date = Field(unique=True, index=True)
    question_uid: uuid.UUID = Field(foreign_key='fermi.uid')
    status: DailyQuestionStatus = Field(
        default=DailyQuestionStatus.SCHEDULED,
        index=True,
    )
    window_start: datetime.datetime = Field(
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )
    window_end: datetime.datetime = Field(
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )
    created_at: datetime.datetime = Field(
        default_factory=utcnow_naive,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )


class DailyQuestionAnswer(SQLModel, table=True):
    """A user's answer submission for a daily question.

    Each user can only submit one answer per daily question.
    Rank is populated after the daily question window closes.
    All timestamps are stored in UTC.
    """

    __tablename__ = 'daily_question_answers'  # type: ignore

    id: int | None = Field(default=None, primary_key=True)
    daily_question_id: int = Field(foreign_key='daily_questions.id', index=True)
    user_firebase_uid: str = Field(index=True)
    answer_number: float
    answer_unit: str | None = None
    score: float
    started_at: datetime.datetime = Field(
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )
    submitted_at: datetime.datetime = Field(
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )
    time_taken_s: float
    rank: int | None = None  # Populated after window closes
    is_post_take: bool = Field(default=False)  # True if answered after DQ closed

"""Precision Rush mode database models."""

import datetime

from fermi_core.utils import utcnow_naive
from sqlmodel import Field, SQLModel


class PrecisionRushRun(SQLModel, table=True):
    """A Precision Rush run session.

    Track a single PR game (exactly 6 questions) for a user. Each run's
    answers are stored in the shared ``answer_events`` table with
    game_id format ``'precision_rush:{run_id}'``.
    """

    __tablename__ = 'precision_rush_runs'  # type: ignore

    id: int | None = Field(default=None, primary_key=True)
    user_firebase_uid: str = Field(index=True)
    started_at: datetime.datetime = Field(default_factory=utcnow_naive)
    ended_at: datetime.datetime | None = None
    questions_answered: int = 0
    total_tas: float = Field(default=0.0, index=True)
    current_question_uid: str = Field(index=True)
    current_deadline: datetime.datetime | None = Field(
        default=None,
        description='Deadline of current question, if active',
    )
    is_completed: bool = False

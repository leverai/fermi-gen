"""Survival mode database models."""

import datetime

from fermi_core.utils import utcnow_naive
from sqlmodel import Field, SQLModel


class SurvivalRun(SQLModel, table=True):
    """A survival mode run session.

    Tracks a single survival game attempt for a user. Each run contains
    multiple answers stored in the shared `answer_events` table with
    game_id format 'survival:{run_id}'.
    """

    __tablename__ = 'survival_runs'  # type: ignore

    id: int | None = Field(default=None, primary_key=True)
    user_firebase_uid: str = Field(index=True)
    started_at: datetime.datetime = Field(default_factory=utcnow_naive)
    ended_at: datetime.datetime | None = None
    questions_answered: int = 0
    total_score: float = 0.0
    current_question_uid: str = Field(
        index=True,
    )  # Question player is currently answering
    current_deadline: datetime.datetime | None = Field(
        default=None,
        description='Deadline of current question, if active',
    )
    is_completed: bool = False  # True if run ended (pass/fail)
    streak: int = Field(default=0, index=True)  # Best streak for leaderboard
    ad_saves_used: int = Field(default=0)  # Times player used ad to continue

"""User model."""

from datetime import datetime

from fermi_core import utcnow_naive
from sqlmodel import Field, SQLModel

from fermi_db.schemas import Locale


class User(SQLModel, table=True):
    """User table."""

    id: int | None = Field(default=None, primary_key=True)
    firebase_uid: str = Field(unique=True, index=True)
    email: str | None = Field(default=None, unique=True, index=True)
    display_name: str | None = None
    picture: str | None = None
    created_at: datetime = Field(default_factory=utcnow_naive)
    updated_at: datetime = Field(default_factory=utcnow_naive)
    locale: Locale = Field(default='US')
    # Login streak fields
    login_streak: int = Field(default=0)
    last_login_at: datetime = Field(default_factory=utcnow_naive)

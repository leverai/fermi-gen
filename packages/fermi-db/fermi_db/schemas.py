"""Pydantic schemas for the fermi-db package."""

from enum import StrEnum
from typing import TYPE_CHECKING

from typing_extensions import TypedDict

if TYPE_CHECKING:
    from pydantic import HttpUrl


class QuestionStatus(StrEnum):
    """Status of a question."""

    PENDING_REVIEW = 'PENDING_REVIEW'
    APPROVED = 'APPROVED'
    REJECTED = 'REJECTED'


class DailyQuestionStatus(StrEnum):
    """Status of a daily question."""

    SCHEDULED = 'SCHEDULED'
    ACTIVE = 'ACTIVE'
    CLOSED = 'CLOSED'


class QuestionDifficulty(StrEnum):
    """Difficulty of a game."""

    EASY = 'EASY'
    MEDIUM = 'MEDIUM'
    HARD = 'HARD'


class QuestionCategory(StrEnum):
    """Category of a game."""

    PLANET_EARTH = 'PLANET_EARTH'
    HUMANITY_BY_NUMBERS = 'HUMANITY_BY_NUMBERS'
    POP_CULTURE = 'POP_CULTURE'
    SHOWER_THOUGHTS = 'SHOWER_THOUGHTS'
    COSMIC_PERSPECTIVE = 'COSMIC_PERSPECTIVE'
    OTHER = 'OTHER'

    @classmethod
    def get_all(cls, *, exclude_other: bool = False) -> list['QuestionCategory']:
        """Get all question categories."""
        if exclude_other:
            return [cat for cat in cls if cat != cls.OTHER]
        return list(cls)


class QuestionAnswer(TypedDict):
    """Answer to a question."""

    number: float
    unit: str | None


class AnswerReference(TypedDict):
    """Reference for the answer."""

    url: 'HttpUrl'
    title: str | None
    content: str | None
    score: float | None
    favicon: 'HttpUrl | None'


class AnswerBare(TypedDict):
    """Player answer."""


class AnswerWithSnippet(TypedDict):
    """Player answer with snippet."""

    number: float
    unit: str | None
    ai_overview: str


class Answer(AnswerWithSnippet):
    """The complete answer to a Fermi question."""

    paragraph: str
    confidence: float
    references: list[AnswerReference]


class Locale(StrEnum):
    """Locale of a user."""

    US = 'US'
    EU = 'EU'

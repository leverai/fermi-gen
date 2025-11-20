"""Base classes for Fermi category."""

from typing import Literal, TypeAlias

from pydantic import BaseModel, Field

TypeDifficulty: TypeAlias = Literal[
    'EASY',
    'MEDIUM',
    'HARD',
]


class QuestionDifficulty(BaseModel):
    """Single `category` item."""

    difficulty: TypeDifficulty = Field(..., description='The question difficulty.')

"""Pipeline-related DB models for seed tracking and question generation."""

import datetime
from typing import Any

import sqlalchemy as sa
from fermi_core.utils import utcnow_naive
from pgvector.sqlalchemy import Vector
from sqlmodel import Field, SQLModel

from fermi_db.schemas import QuestionCategory, QuestionDifficulty


class Seed(SQLModel, table=True):
    """Store unique category seeds for question generation."""

    __tablename__ = 'seeds'  # type: ignore

    id: int | None = Field(default=None, primary_key=True)
    seed: str = Field(unique=True, index=True)
    embedding: list[float] = Field(sa_column=sa.Column(Vector(1536)))
    created_at: datetime.datetime = Field(
        default_factory=utcnow_naive,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )


class RawQuestion(SQLModel, table=True):
    """Accept ALL generated questions (fast inserts, before deduplication)."""

    __tablename__ = 'raw_questions'  # type: ignore

    id: int | None = Field(default=None, primary_key=True)
    seed_id: int | None = Field(default=None, foreign_key='seeds.id', index=True)
    text: str
    embedding: list[float] = Field(sa_column=sa.Column(Vector(1536)))
    source: dict[str, Any] = Field(sa_column=sa.Column(sa.JSON))
    dedup_status: str = Field(default='pending')  # 'pending', 'unique', 'duplicate'
    canonical_question_id: int | None = Field(
        default=None,
        foreign_key='fermi_questions.id',
    )
    created_at: datetime.datetime = Field(
        default_factory=utcnow_naive,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )


class FermiQuestion(SQLModel, table=True):
    """Unique questions only (production table)."""

    __tablename__ = 'fermi_questions'  # type: ignore

    id: int | None = Field(default=None, primary_key=True)
    seed_id: int | None = Field(default=None, foreign_key='seeds.id', index=True)
    text: str
    embedding: list[float] = Field(sa_column=sa.Column(Vector(1536)))
    source: dict[str, Any] = Field(sa_column=sa.Column(sa.JSON))
    category: QuestionCategory | None = Field(default=None)
    difficulty: QuestionDifficulty | None = Field(default=None)
    created_at: datetime.datetime = Field(
        default_factory=utcnow_naive,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )


class FermiAnswer(SQLModel, table=True):
    """Ground truth answers from SerpAPI for Fermi questions."""

    __tablename__ = 'fermi_answers'  # type: ignore

    id: int | None = Field(default=None, primary_key=True)
    question_id: int = Field(foreign_key='fermi_questions.id', unique=True, index=True)
    number: float = Field(description='Numeric answer')
    unit: str | None = Field(default=None, description='Unit or None for dimensionless')
    snippet: str = Field(description='Answer paragraph from search')
    used_ai_overview: bool = Field(description='True if from AI overview')
    success: bool = Field(
        description='True if answering succeeded, False for failed attempts',
    )
    serp_metadata: dict[str, Any] = Field(sa_column=sa.Column(sa.JSON))
    created_at: datetime.datetime = Field(
        default_factory=utcnow_naive,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )


class SeedsUsage(SQLModel, table=True):
    """Track each generation batch with yield statistics."""

    __tablename__ = 'seeds_usage'  # type: ignore

    id: int | None = Field(default=None, primary_key=True)
    seed_id: int = Field(foreign_key='seeds.id', index=True)
    requested: int  # Questions requested from LLM
    generated: int  # Questions LLM actually generated
    yielded: int | None = Field(default=None)  # Unique questions after dedup
    created_at: datetime.datetime = Field(
        default_factory=utcnow_naive,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False), index=True),
    )


class LLMAnswer(SQLModel, table=True):
    """LLM-generated answers for Fermi questions.

    Stores answers from different LLM models (gpt-5.1, gpt-5-mini, gpt-5-nano)
    to allow users to compare their answers with LLMs of different sizes.
    """

    __tablename__ = 'llm_answers'  # type: ignore

    id: int | None = Field(default=None, primary_key=True)
    question_id: int = Field(foreign_key='fermi_questions.id', index=True)
    model: str = Field(
        description='Model name: gpt-5.1, gpt-5-mini, gpt-5-nano',
        index=True,
    )
    number: float = Field(description='Numeric estimate from LLM')
    unit: str | None = Field(default=None, description='Unit or None for dimensionless')
    created_at: datetime.datetime = Field(
        default_factory=utcnow_naive,
        sa_column=sa.Column(sa.TIMESTAMP(timezone=False)),
    )

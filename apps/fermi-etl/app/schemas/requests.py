"""Request schemas for the Fermi ETL Pipeline."""

from typing import Literal

from pydantic import BaseModel, Field


class SeedInsertRequest(BaseModel):
    """Request model for manual seed insertion."""

    seeds: list[str] = Field(
        ...,
        description='List of seed texts to insert (will be preprocessed)',
        min_length=1,
        max_length=100,
    )


class QuestionLiteralRequest(BaseModel):
    """Request model for literal question insertion."""

    questions: list[str] = Field(
        ...,
        description='List of question texts to insert',
        min_length=1,
        max_length=100,
    )
    provider: Literal['human', 'other'] = Field(
        ...,
        description='The provider of the literal questions',
    )


class QuestionLLMRequest(BaseModel):
    """Request model for LLM-based question generation."""

    num_seeds: int = Field(
        ...,
        description='Number of seeds to use for generation',
        gt=0,
        le=100,
    )
    questions_per_seed: int = Field(
        default=20,
        description='Number of questions to generate per seed',
        gt=0,
        le=100,
    )
    mode: Literal['thompson', 'lru'] = Field(
        default='thompson',
        description="Seed selection mode: 'thompson' or 'lru'",
    )


class AnswerRequest(BaseModel):
    """Request model for manual answer generation."""

    question_ids: list[int] = Field(
        ...,
        description='List of question IDs to answer',
        min_length=1,
        max_length=100,
    )


class AnswerUnansweredRequest(BaseModel):
    """Request model for answering unanswered questions."""

    num_questions: int = Field(
        default=50,
        description='Number of unanswered questions to answer',
        gt=0,
        le=200,
    )


class InsertLLMRequest(BaseModel):
    """Request model for composite LLM workflow (generate + answer)."""

    num_seeds: int = Field(
        ...,
        description='Number of seeds to use for generation',
        gt=0,
        le=100,
    )
    questions_per_seed: int = Field(
        default=20,
        description='Number of questions to generate per seed',
        gt=0,
        le=100,
    )
    mode: Literal['thompson', 'lru'] = Field(
        default='thompson',
        description="Seed selection mode: 'thompson' or 'lru'",
    )


class InsertLiteralRequest(BaseModel):
    """Request model for composite literal workflow (insert + answer)."""

    questions: list[str] = Field(
        ...,
        description='List of question texts to insert and answer',
        min_length=1,
        max_length=100,
    )
    provider: Literal['human', 'other'] = Field(
        default='other',
        description='The provider of the literal questions (defaults to other)',
    )


class EnrichmentRequest(BaseModel):
    """Request model for enrichment operations."""

    num_questions: int = Field(
        default=50,
        description='Number of questions to enrich',
        gt=0,
        le=200,
    )

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
    question_model: str = Field(
        default='o3',
        description='LLM model for question generation',
    )
    question_model_provider: str = Field(
        default='openai',
        description='Model provider for question generation',
    )
    question_temperature: float = Field(
        default=1.0,
        le=2.0,
        description='Temperature for question generation (o3 default: 1.0)',
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
    location_model: str = Field(
        default='gpt-5-mini',
        description='Model for location selection',
    )
    extraction_model: str = Field(
        default='gpt-5-mini',
        description='Model for answer extraction',
    )
    answer_model_provider: str = Field(
        default='openai',
        description='Model provider for answer generation',
    )
    confidence_threshold: float = Field(
        default=0.8,
        ge=0.0,
        le=1.0,
        description='Minimum confidence threshold for answers',
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
    # Question generation params
    question_model: str = Field(
        default='o3',
        description='LLM model for question generation',
    )
    question_model_provider: str = Field(
        default='openai',
        description='Model provider for question generation',
    )
    question_temperature: float = Field(
        default=1.0,
        le=2.0,
        description='Temperature for question generation (o3 default: 1.0)',
    )
    # Answer generation params
    location_model: str = Field(
        default='gpt-5-mini',
        description='Model for location selection',
    )
    extraction_model: str = Field(
        default='gpt-5-mini',
        description='Model for answer extraction',
    )
    answer_model_provider: str = Field(
        default='openai',
        description='Model provider for answer generation',
    )
    confidence_threshold: float = Field(
        default=0.8,
        ge=0.0,
        le=1.0,
        description='Minimum confidence threshold for answers',
    )
    # Enrichment params
    category_model: str = Field(
        default='gpt-5-mini',
        description='Model for category classification',
    )
    category_model_provider: str = Field(
        default='openai',
        description='Model provider for category classification',
    )
    difficulty_model: str = Field(
        default='gpt-5-mini',
        description='Model for difficulty assessment',
    )
    difficulty_model_provider: str = Field(
        default='openai',
        description='Model provider for difficulty assessment',
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
    # Answer generation params
    location_model: str = Field(
        default='gpt-5-mini',
        description='Model for location selection',
    )
    extraction_model: str = Field(
        default='gpt-5-mini',
        description='Model for answer extraction',
    )
    answer_model_provider: str = Field(
        default='openai',
        description='Model provider for answer generation',
    )
    confidence_threshold: float = Field(
        default=0.8,
        ge=0.0,
        le=1.0,
        description='Minimum confidence threshold for answers',
    )
    # Enrichment params
    category_model: str = Field(
        default='gpt-5-mini',
        description='Model for category classification',
    )
    category_model_provider: str = Field(
        default='openai',
        description='Model provider for category classification',
    )
    difficulty_model: str = Field(
        default='gpt-5-mini',
        description='Model for difficulty assessment',
    )
    difficulty_model_provider: str = Field(
        default='openai',
        description='Model provider for difficulty assessment',
    )


class EnrichmentRequest(BaseModel):
    """Request model for enrichment operations."""

    num_questions: int = Field(
        default=50,
        description='Number of questions to enrich',
        gt=0,
        le=200,
    )
    model: str = Field(
        default='gpt-5-mini',
        description='Model for enrichment (category or difficulty)',
    )
    model_provider: str = Field(
        default='openai',
        description='Model provider for enrichment',
    )

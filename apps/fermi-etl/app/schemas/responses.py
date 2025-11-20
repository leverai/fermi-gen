"""Response schemas for the Fermi ETL Pipeline."""

from pydantic import BaseModel

from app.services.answer_service import AnswerResult
from app.services.enrichment_service import EnrichmentResult
from app.services.question_service import QuestionBatchResult
from app.services.seed_service import SeedBatchResult


class SeedInsertResponse(BaseModel):
    """Response model for seed insertion."""

    success: bool
    result: SeedBatchResult | None = None
    error: str | None = None


class QuestionResponse(BaseModel):
    """Response model for question generation/insertion."""

    success: bool
    result: QuestionBatchResult | None = None
    error: str | None = None


class AnswerResponse(BaseModel):
    """Response model for answer generation."""

    success: bool
    result: AnswerResult | None = None
    error: str | None = None


class CompositeResponse(BaseModel):
    """Response model for composite workflows (question + answer)."""

    success: bool
    question_result: QuestionBatchResult | None = None
    answer_result: AnswerResult | None = None
    enrichment_result: EnrichmentResult | None = None
    error: str | None = None


class EnrichmentResponse(BaseModel):
    """Response model for enrichment operations."""

    success: bool
    result: EnrichmentResult | None = None
    error: str | None = None

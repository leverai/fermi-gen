"""Schemas for LLM answer operations."""

from pydantic import BaseModel, Field
from typing_extensions import TypedDict


class LLMAnswerInput(TypedDict):
    """Input for a single LLM answer request."""

    question: str
    answer_unit: str | None  # Unit for dimensional questions, None for dimensionless


class LLMChainOutput(BaseModel):
    """Output from LLM answer chain."""

    number: float = Field(..., description='The numeric estimate')


class LLMAnswerOutput(BaseModel):
    """Output from LLM answer operation."""

    number: float = Field(..., description='The numeric estimate')
    unit: str | None = Field(None, description='The unit or None for dimensionless')

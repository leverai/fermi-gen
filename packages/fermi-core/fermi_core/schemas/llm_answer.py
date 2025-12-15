"""Schemas for LLM answer operations."""

from pydantic import BaseModel, Field
from typing_extensions import TypedDict
from pydantic import field_validator


class LLMAnswerInput(TypedDict):
    """Input for a single LLM answer request."""

    question: str
    units_set: (
        list[str] | None
    )  # Available units for dimensional questions, None for dimensionless


class LLMAnswerOutput(BaseModel):
    """Output from LLM answer operation."""

    number: float = Field(..., description='The numeric estimate')
    unit: str | None = Field(
        None,
        description='The unit for dimensional questions, null for dimensionless',
    )

    @field_validator('unit', mode='after')
    @classmethod
    def validate_unit(cls, v: str | None) -> str | None:
        """Ensure dimensionless questions have None unit."""
        if v is None or v.lower() in ('null', 'none', 'nil', '', 'dimensionless'):
            return None
        return v

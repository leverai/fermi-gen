"""Base classes for the answer operation."""

from typing import TypedDict

from pydantic import BaseModel, Field, HttpUrl, field_validator


class ExtractInfoState(TypedDict):
    """State for the extract info chain."""

    question: str
    paragraph: str


class AnswerReference(BaseModel):
    """Reference for the answer."""

    url: HttpUrl = Field(description='The URL of the reference.')
    title: str = Field(description='The title of the reference.')
    content: str | None = Field(
        None,
        description='A snippet of the content from the reference.',
    )
    score: float = Field(
        description='The relevance score of the reference.',
    )
    favicon: HttpUrl | None = Field(
        None,
        description='The favicon of the reference website.',
    )


class TavilySearchResponse(BaseModel):
    """The response from a Tavily search."""

    answer: str = Field(description='The answer paragraph from Tavily.')
    results: list[AnswerReference] = Field(
        default_factory=list,
        description='List of search results.',
    )


class Answer(BaseModel):
    """The complete answer to a Fermi question."""

    paragraph: str = Field(
        ...,
        description='Human-readable paragraph explaining the answer.',
    )
    number: float = Field(..., description='The numeric answer.')
    unit: str | None = None
    confidence: float = Field(
        ...,
        ge=0,
        le=1,
        description='Confidence score in the produced answer [0,1].',
    )
    references: list[AnswerReference] = Field(
        ...,
        description='A list of references used to generate the answer.',
    )

    @field_validator('unit', mode='after')
    @classmethod
    def empty_no_unit(cls, val: str) -> str | None:
        """Convert 'dimensionless', 'unknown', or empty string to empty string."""
        if val and val.lower() in ('dimensionless', 'unknown'):
            return None
        return val


class ExtractedInfo(BaseModel):
    """Information extracted from the question and answer paragraph by the LLM."""

    number: float = Field(..., description='The extracted numeric answer.')
    unit: str = Field(..., description='The unit of the answer.')
    confidence: float = Field(
        ...,
        ge=0,
        le=1,
        description="Confidence score in the answer's correctness.",
    )

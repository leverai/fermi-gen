"""Schemas for SerpAPI-based answer pipeline."""

from typing import Any, Literal

from pint import UnitRegistry
from pydantic import BaseModel, Field, computed_field

ureg = UnitRegistry()


def _flatten_text_blocks(text_blocks: list[dict[str, Any]]) -> str:
    """Recursively extract all snippets from text_blocks.

    Handles nested structures with 'list' fields and extracts all 'snippet' values.
    Joins them with spaces to create a comprehensive answer paragraph.

    Args:
        text_blocks: List of text block dictionaries from SerpAPI AI Overview

    Returns:
        Single string with all snippets concatenated

    """
    snippets: list[str] = []

    def extract_snippets(blocks: list[dict[str, Any]]) -> None:
        """Recursively extract snippets from blocks and nested lists."""
        for block in blocks:
            # Extract snippet from current block
            if snippet := block.get('snippet'):
                snippets.append(snippet)

            # Recursively extract from nested lists
            if nested_list := block.get('list'):
                extract_snippets(nested_list)

    extract_snippets(text_blocks)
    return ' '.join(snippets)


# Valid units - curated list matching units.py
VALID_UNITS = Literal[
    'ounce',
    'pound',
    'ton',
    'gram',
    'kilogram',
    'metric_ton',
    'inch',
    'foot',
    'mile',
    'centimeter',
    'meter',
    'kilometer',
    'foot ** 2',
    'acre',
    'mile ** 2',
    'meter ** 2',
    'hectare',
    'km ** 2',
    'gallon',
    'liter',
    'meter ** 3',
    'foot ** 3',
    'km ** 3',
    'mile ** 3',
    'quart',
    'second',
    'minute',
    'hour',
    'day',
    'week',
    'month',
    'year',
    'century',
    'millennium',
    'fahrenheit',
    'celsius',
    'kilobyte',
    'megabyte',
    'gigabyte',
    'terabyte',
    'petabyte',
    'dimensionless',
]


class SerpAIOverview(BaseModel):
    """AI Overview from Google Search via SerpAPI."""

    text_blocks: list[dict[str, Any]]  # Contains snippets, lists, headings
    references: list[dict[str, Any]]  # Source references with links

    model_config = {'extra': 'allow'}  # Allow extra fields from SerpAPI

    @computed_field
    @property
    def snippet(self) -> str:
        """Extract complete answer by flattening all text_blocks.

        Recursively extracts all snippets from text_blocks (including nested lists)
        to create a comprehensive answer paragraph. This ensures we capture the
        complete answer even when it spans multiple blocks (summary + conclusion).

        Returns:
            Flattened snippet with all text_blocks content

        """
        return _flatten_text_blocks(self.text_blocks)


class SerpAIOverviewX(BaseModel):
    """AI Overview value when an extra request is needed."""

    page_token: str
    serpapi_link: str


class SerpRelatedQuestion(BaseModel):
    """Related question from Google Search."""

    question: str
    snippet: str | None = None

    model_config = {'extra': 'allow'}  # Allow extra fields from SerpAPI


class SerpSearchResult(BaseModel):
    """Complete search result from SerpAPI - lenient on extra fields."""

    ai_overview: SerpAIOverview | SerpAIOverviewX | None = None
    related_questions: list[SerpRelatedQuestion] = []

    model_config = {'extra': 'allow'}  # Allow extra fields from SerpAPI


class SnippetCandidate(BaseModel):
    """A candidate snippet extracted from search results."""

    snippet: str
    metadata: dict[str, Any]  # Full context (ai_overview dict or related_question dict)
    source: Literal['ai_overview', 'related_question']


class LocationSelection(BaseModel):
    """Selected location for Google search."""

    gl: str = Field(description='Two-letter country code (us, uk, ca, au, etc.)')
    reasoning: str = Field(description='Brief reasoning for selection')


class ExtractedInfo(BaseModel):
    """Information extracted from snippet - with validated unit."""

    number: float = Field(description='Numeric answer in scientific notation')
    unit: VALID_UNITS = Field(description='Unit from predefined list')
    confidence: float = Field(ge=0, le=1, description='Extraction confidence')

    def to_base_unit(self) -> tuple[float, str | None]:
        """Convert to base unit."""
        if self.unit is None:
            return self.number, None
        quantity_base = ureg.Quantity(self.number, self.unit).to_base_units()
        return quantity_base.magnitude, str(quantity_base.units)


class SerpAnswer(BaseModel):
    """Final answer from SerpAPI pipeline - DB ready."""

    number: float = Field(description='Numeric answer')
    unit: str | None = Field(description='Unit or None for dimensionless')
    snippet: str = Field(description='Answer paragraph used')
    used_ai_overview: bool = Field(
        description='True if ai_overview used, False if related_question',
    )
    metadata: dict[str, Any] = Field(
        description='Full ai_overview or related_question dict from SerpAPI',
    )
    confidence: float = Field(
        ge=0.8,
        le=1.0,
        description='Extraction confidence (min 0.8)',
    )

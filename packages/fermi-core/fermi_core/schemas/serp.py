"""Schemas for SerpAPI-based answer pipeline."""

from typing import Any, Literal

from pint import UnitRegistry
from pydantic import BaseModel, Field, computed_field, field_validator

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


class GoogleAIModeResult(BaseModel):
    """Result from Google AI Mode API.

    The AI Mode engine returns structured text_blocks directly,
    without the need for page token fallback requests.
    """

    text_blocks: list[dict[str, Any]] = []
    references: list[dict[str, Any]] = []

    model_config = {'extra': 'allow'}  # Allow extra fields from SerpAPI

    @computed_field
    @property
    def snippet(self) -> str:
        """Extract complete answer by flattening all text_blocks.

        Recursively extracts all snippets from text_blocks (including nested lists)
        to create a comprehensive answer paragraph.

        Returns:
            Flattened snippet with all text_blocks content

        """
        return _flatten_text_blocks(self.text_blocks)


class SnippetCandidate(BaseModel):
    """A candidate snippet extracted from search results."""

    snippet: str
    metadata: dict[str, Any]  # Full context from AI Mode result
    source: Literal['ai_mode'] = 'ai_mode'


class LocationSelection(BaseModel):
    """Selected location for Google search."""

    gl: str = Field(description='Two-letter country code (us, uk, ca, au, etc.)')
    reasoning: str = Field(description='Brief reasoning for selection')


class ExtractedInfo(BaseModel):
    """Information extracted from snippet - with validated unit."""

    number: float = Field(description='Numeric answer in scientific notation', gt=0)
    unit: VALID_UNITS = Field(description='Unit from predefined list.')
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

    @field_validator('unit', mode='after')
    @classmethod
    def _no_unit_as_none(cls, v: Literal['dimensionless'] | str) -> str | None:
        """Convert 'dimensionless' to None."""
        if v == 'dimensionless':
            return None
        return v

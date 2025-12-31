"""Schemas for SerpAPI-based answer pipeline."""

import math
from typing import Any, Literal, Self

from pint import UnitRegistry
from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    computed_field,
    field_validator,
    model_validator,
)

ureg = UnitRegistry()


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

    model_config = ConfigDict(extra='ignore')  # Ignore extra fields from SerpAPI

    text_blocks: list[dict[str, Any]] = []
    references: list[dict[str, Any]] = []

    @computed_field
    @property
    def snippet_json(self) -> str:
        """Json serialized text_blocks."""
        return self.model_dump_json()


class SnippetCandidate(BaseModel):
    """A candidate snippet extracted from search results."""

    snippet_json: str
    metadata: dict[str, Any]  # Full context from AI Mode result
    source: Literal['ai_mode'] = 'ai_mode'


class LocationSelection(BaseModel):
    """Selected location for Google search."""

    gl: str = Field(description='Two-letter country code (us, uk, ca, au, etc.)')
    reasoning: str = Field(description='Brief reasoning for selection')


class ExtractedInfo(BaseModel):
    """Information extracted from snippet - with validated unit.

    Uses separate coefficient and exponent fields to avoid OpenAI structured
    outputs truncating scientific notation. The number is computed as:
    number = coefficient * 10^exponent
    """

    coefficient: float = Field(
        description=(
            'The coefficient part of the scientific notation. '
            'For 27.5 million (2.75e7), this would be 2.75. '
            'Must be between 1.0 and 10.0 for proper scientific notation.'
        ),
        gt=0,
    )
    exponent: int = Field(
        description=(
            'The exponent (power of 10) in scientific notation. '
            'For 27.5 million (2.75e7), this would be 7. '
            'For 3,500 (3.5e3), this would be 3.'
        ),
    )
    unit: VALID_UNITS = Field(description='Unit from predefined list.')
    confidence: float = Field(ge=0, le=1, description='Extraction confidence')

    @computed_field
    @property
    def number(self) -> float:
        """Compute the full number from coefficient and exponent."""
        return self.coefficient * (10**self.exponent)

    @field_validator('unit', mode='after')
    @classmethod
    def _no_unit_as_none(cls, v: Literal['dimensionless'] | str) -> str | None:
        """Convert 'dimensionless' to None."""
        if v == 'dimensionless':
            return None
        return v

    @model_validator(mode='after')
    def to_base_unit(self) -> Self:
        """Convert to base unit."""
        if self.unit is None:
            return self
        # Compute number, convert to base units, then update coefficient/exponent
        quantity_base = ureg.Quantity(self.number, self.unit).to_base_units()
        base_number = quantity_base.magnitude
        assert base_number > 0, 'Base number must be greater than 0'
        # Recompute coefficient and exponent from base number
        self.exponent = math.floor(math.log10(base_number))
        self.coefficient = base_number / (10**self.exponent)
        self.unit = str(quantity_base.units)  # type: ignore[reportAttributeAccessIssue]
        return self


class SerpAnswer(BaseModel):
    """Final answer from SerpAPI pipeline - DB ready."""

    number: float = Field(description='Numeric answer')
    unit: str | None = Field(description='Unit or None for dimensionless')
    snippet: str = Field(description='SerpAPI response json string.')
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

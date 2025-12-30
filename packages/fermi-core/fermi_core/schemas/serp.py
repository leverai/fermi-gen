"""Schemas for SerpAPI-based answer pipeline."""

import math
from typing import Any, Literal, Self

from pint import UnitRegistry
from pydantic import (
    BaseModel,
    Field,
    computed_field,
    field_validator,
    model_validator,
)

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


def _format_snippet_with_inline_code(
    snippet: str,
    inline_code: list[str] | None,
) -> str:
    """Format snippet text with inline code markers.

    Wraps occurrences of inline_code words with backticks.

    Args:
        snippet: The text snippet to format
        inline_code: List of words to wrap in backticks

    Returns:
        Formatted snippet with inline code

    """
    if not inline_code or not snippet:
        return snippet

    result = snippet
    for code_word in inline_code:
        if code_word in result:
            # Only replace if not already wrapped in backticks
            result = result.replace(code_word, f'`{code_word}`')
    return result


def _render_table_to_markdown(table: list[list[str]]) -> str:
    """Convert a 2D table array to Markdown table format.

    First row is treated as headers.

    Args:
        table: 2D list where first row is headers

    Returns:
        Markdown-formatted table string

    """
    if not table or not table[0]:
        return ''

    lines: list[str] = []

    # Header row
    header = table[0]
    lines.append('| ' + ' | '.join(str(cell) for cell in header) + ' |')

    # Separator row
    lines.append('| ' + ' | '.join('---' for _ in header) + ' |')

    # Data rows
    for row in table[1:]:
        # Ensure row has same number of columns as header
        padded_row = list(row) + [''] * (len(header) - len(row))
        lines.append(
            '| ' + ' | '.join(str(cell) for cell in padded_row[: len(header)]) + ' |',
        )

    return '\n'.join(lines)


def _text_blocks_to_markdown(
    text_blocks: list[dict[str, Any]],
    heading_level: int = 2,
    list_indent: int = 0,
) -> str:
    """Convert SerpAPI text_blocks to Markdown format.

    Handles all known block types: heading, paragraph, list, code_block, table,
    expandable, comparison. Unknown types fall back to paragraph formatting.

    Supports recursive nesting of text_blocks within list items.

    Args:
        text_blocks: List of text block dictionaries from SerpAPI AI Mode
        heading_level: Starting heading level (default 2 = ##)
        list_indent: Current list indentation level (0 = top level)

    Returns:
        Formatted Markdown string

    """
    if not text_blocks:
        return ''

    output_parts: list[str] = []
    indent_prefix = '  ' * list_indent

    for block in text_blocks:
        block_type = block.get('type', 'paragraph')
        snippet = block.get('snippet', '')
        inline_code = block.get('snippet_inline_code')

        # Format snippet with inline code if present
        formatted_snippet = _format_snippet_with_inline_code(snippet, inline_code)

        if block_type == 'heading':
            # Render as Markdown heading
            heading_prefix = '#' * min(heading_level, 6)
            output_parts.append(f'{heading_prefix} {formatted_snippet}')

        elif block_type == 'paragraph':
            # Render as plain paragraph
            if formatted_snippet:
                output_parts.append(formatted_snippet)

        elif block_type == 'list':
            # Render list items
            list_items = block.get('list', [])
            for item in list_items:
                item_snippet = item.get('snippet', '')
                item_title = item.get('title', '')
                item_inline_code = item.get('snippet_inline_code')

                # Format item snippet
                formatted_item = _format_snippet_with_inline_code(
                    item_snippet,
                    item_inline_code,
                )

                # Build list item text
                if item_title and formatted_item:
                    item_text = f'**{item_title}**: {formatted_item}'
                elif item_title:
                    item_text = f'**{item_title}**'
                else:
                    item_text = formatted_item

                if item_text:
                    output_parts.append(f'{indent_prefix}- {item_text}')

                # Handle code_block within list item
                if item_code_block := item.get('code_block'):
                    lang = item_code_block.get('language', '')
                    code = item_code_block.get('code', '')
                    if code:
                        # Indent code block for list context
                        code_indent = indent_prefix + '  '
                        code_lines = code.rstrip('\n').split('\n')
                        indented_code = '\n'.join(
                            f'{code_indent}{line}' for line in code_lines
                        )
                        output_parts.append(
                            f'{code_indent}```{lang}\n{indented_code}\n{code_indent}```',
                        )

                # Handle nested list within list item
                if nested_list := item.get('list'):
                    nested_md = _text_blocks_to_markdown(
                        [{'type': 'list', 'list': nested_list}],
                        heading_level=heading_level + 1,
                        list_indent=list_indent + 1,
                    )
                    if nested_md.strip():
                        output_parts.append(nested_md)

                # Handle nested text_blocks within list item
                if nested_blocks := item.get('text_blocks'):
                    nested_md = _text_blocks_to_markdown(
                        nested_blocks,
                        heading_level=heading_level + 1,
                        list_indent=list_indent + 1,
                    )
                    if nested_md.strip():
                        output_parts.append(nested_md)

        elif block_type == 'code_block':
            # Render fenced code block
            language = block.get('language', '')
            code = block.get('code', '')
            if code:
                output_parts.append(f'```{language}\n{code.rstrip()}\n```')

        elif block_type == 'table':
            # Render as Markdown table
            table_data = block.get('table', [])
            if table_data:
                table_md = _render_table_to_markdown(table_data)
                if table_md:
                    output_parts.append(table_md)

        elif block_type in ('expandable', 'comparison'):
            # Treat as a section - render snippet and any nested content
            if formatted_snippet:
                output_parts.append(formatted_snippet)
            # Handle any nested text_blocks
            if nested_blocks := block.get('text_blocks'):
                nested_md = _text_blocks_to_markdown(
                    nested_blocks,
                    heading_level=heading_level + 1,
                    list_indent=list_indent,
                )
                if nested_md.strip():
                    output_parts.append(nested_md)

        else:
            # Unknown type - fallback to paragraph rendering
            if formatted_snippet:
                output_parts.append(formatted_snippet)

    return '\n\n'.join(output_parts)


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
        """Convert text_blocks to formatted Markdown.

        Recursively converts all text_blocks (including nested structures)
        to properly formatted Markdown for display to users.

        Returns:
            Markdown-formatted string with all content

        """
        return _text_blocks_to_markdown(self.text_blocks)


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

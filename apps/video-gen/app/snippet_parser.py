"""Parse SerpAPI Google AI Mode snippet JSON and convert to Markdown.

The snippet field in Fermi objects is a JSON string containing a SerpAPI response
with text_blocks (heading, paragraph, list, code_block, table, expandable, and
comparison) and references. This module parses that schema and renders it as
human-readable Markdown.
"""

from __future__ import annotations

import json
import logging
from typing import Any, Literal

from pydantic import BaseModel, Field

logger = logging.getLogger(__name__)


# -----------------------------------------------------------------------------
# Pydantic Models mirroring the SerpAPI schema (and Dart serp_text_block.dart)
# -----------------------------------------------------------------------------


class SerpReference(BaseModel):
    """A reference/source citation."""

    title: str = ''
    link: str = ''
    snippet: str | None = None
    source: str | None = None
    index: int = 0


class SerpCodeBlock(BaseModel):
    """A code block with optional language specification."""

    type: Literal['code_block'] = 'code_block'
    code: str = ''
    language: str | None = None

    @classmethod
    def from_json(cls, data: dict[str, Any]) -> SerpCodeBlock:
        """Parse from JSON dict, handling both 'snippet' and 'code' fields."""
        return cls(
            code=data.get('snippet') or data.get('code') or '',
            language=data.get('language'),
        )


class SerpListItem(BaseModel):
    """An item within a list block."""

    snippet: str | None = None
    snippet_latex: list[str] = Field(default_factory=list, alias='snippet_latex')
    text_blocks: list[SerpTextBlock] = Field(default_factory=list)
    nested_list: list[SerpListItem] = Field(default_factory=list, alias='list')
    code_block: SerpCodeBlock | None = None


class SerpTextBlock(BaseModel):
    """A text block in the SerpAPI response.

    The type field determines how to render this block:
    - heading: Section heading (## in Markdown)
    - paragraph: Plain text with optional highlighted words
    - list: Bullet list with nested items
    - code_block: Fenced code block
    - table: Markdown table
    - expandable: Collapsible section (rendered as heading + content)
    - comparison: Plain text (treated like paragraph)
    """

    type: str = 'paragraph'
    snippet: str = ''
    snippet_highlighted_words: list[str] = Field(default_factory=list)
    snippet_latex: list[str] = Field(default_factory=list)
    reference_indexes: list[int] = Field(default_factory=list)

    # List-specific fields
    list_items: list[SerpListItem] = Field(default_factory=list, alias='list')

    # Table-specific fields
    table: list[list[str]] = Field(default_factory=list)

    # Code block-specific fields
    code: str = ''
    language: str | None = None

    # Expandable-specific fields
    title: str | None = None
    text_blocks: list[SerpTextBlock] = Field(default_factory=list)


class SerpAiResponse(BaseModel):
    """Top-level AI response containing text_blocks and references."""

    text_blocks: list[SerpTextBlock] = Field(default_factory=list)
    references: list[SerpReference] = Field(default_factory=list)

    @classmethod
    def try_parse(cls, json_string: str) -> SerpAiResponse | None:
        """Parse from JSON string. Returns None if parsing fails."""
        try:
            data = json.loads(json_string)
            return cls.model_validate(data)
        except (json.JSONDecodeError, ValueError):
            logger.exception('Failed to parse snippet JSON')
            return None


# -----------------------------------------------------------------------------
# Markdown Rendering
# -----------------------------------------------------------------------------


def _render_highlighted_text(text: str, highlighted_words: list[str]) -> str:
    """Render text with highlighted words as bold."""
    if not highlighted_words:
        return text

    result = text
    for word in highlighted_words:
        # Only replace first occurrence to avoid double-bolding
        if word in result:
            result = result.replace(word, f'**{word}**', 1)
    return result


def _render_list_item(item: SerpListItem, indent_level: int = 0) -> list[str]:
    """Render a list item and its nested content."""
    lines: list[str] = []
    indent = '  ' * indent_level

    if item.snippet:
        lines.append(f'{indent}- {item.snippet}')

    # Nested text blocks
    for block in item.text_blocks:
        block_lines = _render_text_block(block, indent_level + 1)
        lines.extend(block_lines)

    # Nested list items
    for nested_item in item.nested_list:
        lines.extend(_render_list_item(nested_item, indent_level + 1))

    # Code block within list item
    if item.code_block:
        lang = item.code_block.language or ''
        lines.append(f'{indent}  ```{lang}')
        for code_line in item.code_block.code.split('\n'):
            lines.append(f'{indent}  {code_line}')
        lines.append(f'{indent}  ```')

    return lines


def _render_text_block(block: SerpTextBlock, indent_level: int = 0) -> list[str]:
    """Render a single text block to Markdown lines."""
    lines: list[str] = []
    indent = '  ' * indent_level

    match block.type:
        case 'heading':
            lines.append('')
            lines.append(f'{indent}## {block.snippet}')
            lines.append('')

        case 'paragraph' | 'comparison':
            text = _render_highlighted_text(
                block.snippet,
                block.snippet_highlighted_words,
            )
            if text:
                lines.append(f'{indent}{text}')
                lines.append('')

        case 'list':
            for item in block.list_items:
                lines.extend(_render_list_item(item, indent_level))
            lines.append('')

        case 'code_block':
            code = block.code or block.snippet
            lang = block.language or ''
            lines.append(f'{indent}```{lang}')
            for code_line in code.split('\n'):
                lines.append(f'{indent}{code_line}')
            lines.append(f'{indent}```')
            lines.append('')

        case 'table':
            if block.table:
                # First row is headers
                headers = block.table[0] if block.table else []
                if headers:
                    lines.append(f'{indent}| ' + ' | '.join(headers) + ' |')
                    lines.append(
                        f'{indent}| ' + ' | '.join(['---'] * len(headers)) + ' |',
                    )

                    # Data rows
                    for row in block.table[1:]:
                        lines.append(f'{indent}| ' + ' | '.join(row) + ' |')
                    lines.append('')

        case 'expandable':
            if block.title:
                lines.append('')
                lines.append(f'{indent}### {block.title}')
                lines.append('')
            for nested_block in block.text_blocks:
                lines.extend(_render_text_block(nested_block, indent_level))

        case _:
            # Unknown type, treat as paragraph
            if block.snippet:
                lines.append(f'{indent}{block.snippet}')
                lines.append('')

    return lines


def _render_references(references: list[SerpReference]) -> list[str]:
    """Render references section as numbered list with links."""
    if not references:
        return []

    lines = ['', '---', '', '## Sources', '']
    for ref in sorted(references, key=lambda r: r.index):
        source_text = f' ({ref.source})' if ref.source else ''
        lines.append(f'{ref.index + 1}. [{ref.title}]({ref.link}){source_text}')

    return lines


def convert_to_markdown(snippet_json: str) -> str:
    """Convert a SerpAPI snippet JSON string to Markdown.

    Args:
        snippet_json: The JSON string from Fermi.snippet

    Returns:
        Human-readable Markdown string, or empty string if parsing fails.

    """
    response = SerpAiResponse.try_parse(snippet_json)
    if not response:
        return ''

    lines: list[str] = []

    # Render all text blocks
    for block in response.text_blocks:
        lines.extend(_render_text_block(block))

    # Render references at the end
    lines.extend(
        _render_references(response.references),
    )

    return '\n'.join(lines).strip() + '\n'


def delatex_markdown(md_text: str) -> str:
    """Convert LaTeX in Markdown to plain text."""
    import re

    from bs4 import BeautifulSoup
    from markdown import markdown
    from pylatexenc.latex2text import LatexNodes2Text

    # 1. Convert LaTeX equations to Unicode text
    # This handles simple things like \approx or \pi
    text_with_unicode_math = LatexNodes2Text().latex_to_text(md_text)

    # 2. Convert Markdown to HTML, then strip tags for clean text
    html = markdown(text_with_unicode_math)
    plain_text = ''.join(BeautifulSoup(html, 'html.parser').find_all(string=True))

    # 3. Custom Cleanup for Fermi Math (Scientific Notation)
    # Convert "10^6" to "10⁶" for readability
    superscripts = {
        '0': '⁰',
        '1': '¹',
        '2': '²',
        '3': '³',
        '4': '⁴',
        '5': '⁵',
        '6': '⁶',
        '7': '⁷',
        '8': '⁸',
        '9': '⁹',
        '-': '⁻',
    }

    def replace_exponent(match: re.Match) -> str:
        """Replace 10^x with 10⁶."""
        base, exp = match.groups()
        return base + ''.join(superscripts.get(c, c) for c in exp)

    # Regex to find 10^x patterns
    plain_text = re.sub(r'(10)\^([0-9\-]+)', replace_exponent, plain_text)

    return plain_text


def convert_to_text(snippet_json: str) -> str:
    """Convert a SerpAPI snippet JSON string to plain text."""
    return delatex_markdown(convert_to_markdown(snippet_json))

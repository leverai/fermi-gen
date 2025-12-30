"""Unit tests for text_blocks to Markdown conversion."""

import pytest
from fermi_core.schemas.serp import (
    _format_snippet_with_inline_code,
    _render_table_to_markdown,
    _text_blocks_to_markdown,
)


class TestFormatSnippetWithInlineCode:
    """Tests for inline code formatting."""

    def test_no_inline_code_returns_original(self) -> None:
        """Test that snippet without inline code is unchanged."""
        snippet = 'This is a regular snippet.'
        assert _format_snippet_with_inline_code(snippet, None) == snippet
        assert _format_snippet_with_inline_code(snippet, []) == snippet

    def test_wraps_inline_code_words(self) -> None:
        """Test that inline code words are wrapped in backticks."""
        snippet = 'Use the each method for iteration.'
        result = _format_snippet_with_inline_code(snippet, ['each'])
        assert result == 'Use the `each` method for iteration.'

    def test_multiple_inline_code_words(self) -> None:
        """Test multiple inline code words are wrapped."""
        snippet = 'The each method and map function are useful.'
        result = _format_snippet_with_inline_code(snippet, ['each', 'map'])
        assert result == 'The `each` method and `map` function are useful.'

    def test_empty_snippet_returns_empty(self) -> None:
        """Test empty snippet handling."""
        assert _format_snippet_with_inline_code('', ['code']) == ''


class TestRenderTableToMarkdown:
    """Tests for table rendering."""

    def test_simple_table(self) -> None:
        """Test basic table rendering."""
        table = [
            ['Name', 'Age'],
            ['Alice', '30'],
            ['Bob', '25'],
        ]
        result = _render_table_to_markdown(table)
        expected = '| Name | Age |\n| --- | --- |\n| Alice | 30 |\n| Bob | 25 |'
        assert result == expected

    def test_empty_table(self) -> None:
        """Test empty table returns empty string."""
        assert _render_table_to_markdown([]) == ''
        assert _render_table_to_markdown([[]]) == ''

    def test_padded_rows(self) -> None:
        """Test that short rows are padded."""
        table = [
            ['Col1', 'Col2', 'Col3'],
            ['A'],  # Short row
        ]
        result = _render_table_to_markdown(table)
        assert '| A |  |  |' in result


class TestTextBlocksToMarkdown:
    """Tests for the main text_blocks to Markdown conversion."""

    def test_empty_blocks(self) -> None:
        """Test empty input returns empty string."""
        assert _text_blocks_to_markdown([]) == ''

    def test_paragraph_block(self) -> None:
        """Test paragraph rendering."""
        blocks = [{'type': 'paragraph', 'snippet': 'This is a paragraph.'}]
        result = _text_blocks_to_markdown(blocks)
        assert result == 'This is a paragraph.'

    def test_heading_block(self) -> None:
        """Test heading rendering."""
        blocks = [{'type': 'heading', 'snippet': 'Section Title'}]
        result = _text_blocks_to_markdown(blocks)
        assert result == '## Section Title'

    def test_simple_list(self) -> None:
        """Test simple list rendering."""
        blocks = [
            {
                'type': 'list',
                'list': [
                    {'snippet': 'Item one'},
                    {'snippet': 'Item two'},
                ],
            },
        ]
        result = _text_blocks_to_markdown(blocks)
        assert '- Item one' in result
        assert '- Item two' in result

    def test_list_with_title(self) -> None:
        """Test list items with titles."""
        blocks = [
            {
                'type': 'list',
                'list': [
                    {'title': 'Feature', 'snippet': 'Description of feature'},
                ],
            },
        ]
        result = _text_blocks_to_markdown(blocks)
        assert '- **Feature**: Description of feature' in result

    def test_code_block(self) -> None:
        """Test code block rendering."""
        blocks = [
            {
                'type': 'code_block',
                'language': 'python',
                'code': 'print("Hello")',
            },
        ]
        result = _text_blocks_to_markdown(blocks)
        assert '```python' in result
        assert 'print("Hello")' in result
        assert '```' in result

    def test_table_block(self) -> None:
        """Test table block rendering."""
        blocks = [
            {
                'type': 'table',
                'table': [
                    ['Team', 'Seasons'],
                    ['Lakers', '2018-present'],
                ],
            },
        ]
        result = _text_blocks_to_markdown(blocks)
        assert '| Team | Seasons |' in result
        assert '| Lakers | 2018-present |' in result

    def test_nested_text_blocks_in_list(self) -> None:
        """Test nested text_blocks within list items."""
        blocks = [
            {
                'type': 'list',
                'list': [
                    {
                        'text_blocks': [
                            {'type': 'heading', 'snippet': 'Nested Heading'},
                            {'type': 'paragraph', 'snippet': 'Nested paragraph.'},
                        ],
                    },
                ],
            },
        ]
        result = _text_blocks_to_markdown(blocks)
        assert '### Nested Heading' in result
        assert 'Nested paragraph.' in result

    def test_inline_code_in_paragraph(self) -> None:
        """Test inline code formatting in paragraphs."""
        blocks = [
            {
                'type': 'paragraph',
                'snippet': 'Use the each method for iteration.',
                'snippet_inline_code': ['each'],
            },
        ]
        result = _text_blocks_to_markdown(blocks)
        assert '`each`' in result

    def test_unknown_type_fallback(self) -> None:
        """Test that unknown types fall back to paragraph rendering."""
        blocks = [{'type': 'unknown_type', 'snippet': 'Some content'}]
        result = _text_blocks_to_markdown(blocks)
        assert result == 'Some content'

    def test_mixed_content(self) -> None:
        """Test a mix of different block types."""
        blocks = [
            {'type': 'heading', 'snippet': 'Title'},
            {'type': 'paragraph', 'snippet': 'Introduction.'},
            {
                'type': 'list',
                'list': [
                    {'snippet': 'Point A'},
                    {'snippet': 'Point B'},
                ],
            },
        ]
        result = _text_blocks_to_markdown(blocks)
        assert '## Title' in result
        assert 'Introduction.' in result
        assert '- Point A' in result
        assert '- Point B' in result


class TestCoffeeExample:
    """Test with the real Coffee example from SerpAPI."""

    @pytest.fixture
    def coffee_text_blocks(self) -> list[dict]:
        """Return the Coffee example text_blocks."""
        return [
            {
                'type': 'paragraph',
                'snippet': 'Coffee is a popular brewed beverage made from the roasted and ground seeds of the coffee plant.',  # noqa: E501
            },
            {'type': 'heading', 'snippet': 'Types of beans and roasts'},
            {
                'type': 'paragraph',
                'snippet': 'The flavor profile of coffee varies depending on the bean species, growing region, and roasting process.',  # noqa: E501
            },
            {'type': 'paragraph', 'snippet': 'Bean types:'},
            {
                'type': 'list',
                'list': [
                    {
                        'snippet': 'Arabica: Accounts for roughly 60% of global production.',  # noqa: E501
                    },
                    {
                        'snippet': 'Robusta: A heartier, more disease-resistant bean.',
                    },
                ],
            },
            {'type': 'heading', 'snippet': 'Brewing methods'},
            {
                'type': 'paragraph',
                'snippet': 'There are many ways to prepare coffee, each producing a different result:',  # noqa: E501
            },
            {
                'type': 'list',
                'list': [
                    {'snippet': 'Drip coffee: A common method.'},
                    {'snippet': 'Pour-over: Manual hot water pour.'},
                    {'snippet': 'French press: Steeped and pressed.'},
                    {'snippet': 'Espresso: Concentrated shot.'},
                ],
            },
            {'type': 'heading', 'snippet': 'Health considerations'},
            {
                'type': 'paragraph',
                'snippet': 'When consumed in moderation, coffee is associated with several health benefits.',  # noqa: E501
            },
            {
                'type': 'list',
                'list': [
                    {
                        'text_blocks': [
                            {'type': 'heading', 'snippet': 'Potential benefits'},
                            {
                                'type': 'list',
                                'list': [
                                    {
                                        'snippet': 'Source of antioxidants: Coffee is rich in antioxidants.',  # noqa: E501
                                    },
                                    {
                                        'snippet': 'Reduced disease risk: Studies suggest lower risk of type 2 diabetes.',  # noqa: E501
                                    },
                                ],
                            },
                        ],
                    },
                    {
                        'text_blocks': [
                            {'type': 'heading', 'snippet': 'Potential side effects'},
                            {
                                'type': 'list',
                                'list': [
                                    {
                                        'snippet': 'Anxiety and jitters: High doses can cause restlessness.',  # noqa: E501
                                    },
                                    {
                                        'snippet': 'Sleep disruption: Drinking coffee late can interfere with sleep.',  # noqa: E501
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ]

    def test_coffee_example_has_headings(
        self,
        coffee_text_blocks: list[dict],
    ) -> None:
        """Test that headings are rendered correctly."""
        result = _text_blocks_to_markdown(coffee_text_blocks)
        assert '## Types of beans and roasts' in result
        assert '## Brewing methods' in result
        assert '## Health considerations' in result

    def test_coffee_example_has_lists(
        self,
        coffee_text_blocks: list[dict],
    ) -> None:
        """Test that list items are rendered."""
        result = _text_blocks_to_markdown(coffee_text_blocks)

        assert '- Arabica:' in result
        assert '- Robusta:' in result
        assert '- Drip coffee:' in result
        assert '- Espresso:' in result

    def test_coffee_example_has_nested_content(
        self,
        coffee_text_blocks: list[dict],
    ) -> None:
        """Test that nested headings and lists are rendered."""
        result = _text_blocks_to_markdown(coffee_text_blocks)

        # Nested headings should be one level deeper
        assert '### Potential benefits' in result
        assert '### Potential side effects' in result

        # Nested list items
        assert 'Source of antioxidants' in result
        assert 'Anxiety and jitters' in result

    def test_coffee_example_overall_structure(
        self,
        coffee_text_blocks: list[dict],
    ) -> None:
        """Test the overall Markdown structure."""
        result = _text_blocks_to_markdown(coffee_text_blocks)

        # Should have multiple sections separated by empty lines
        assert '\n\n' in result

        # Opening paragraph should be present
        assert 'Coffee is a popular brewed beverage' in result

        # Should be valid Markdown with proper heading hierarchy
        lines = result.split('\n')
        heading_lines = [line for line in lines if line.startswith('#')]

        # Should have h2 and h3 headings
        h2_count = sum(1 for h in heading_lines if h.startswith('## '))
        h3_count = sum(1 for h in heading_lines if h.startswith('### '))

        assert h2_count >= 3  # Main section headings
        assert h3_count >= 2  # Nested headings (benefits, side effects)

"""Tests for snippet_parser module."""

import json

from app.snippet_parser import (
    SerpAiResponse,
    convert_to_markdown,
)


class TestSerpAiResponse:
    """Tests for SerpAiResponse parsing."""

    def test_try_parse_empty_text_blocks(self) -> None:
        """Parse response with empty text_blocks returns valid empty response."""
        json_str = '{"text_blocks": [], "references": []}'
        response = SerpAiResponse.try_parse(json_str)
        assert response is not None
        assert response.text_blocks == []
        assert response.references == []

    def test_try_parse_invalid_json(self) -> None:
        """Parse invalid JSON returns None."""
        result = SerpAiResponse.try_parse('not valid json')
        assert result is None

    def test_try_parse_heading_block(self) -> None:
        """Parse heading block correctly."""
        data = {
            'text_blocks': [{'type': 'heading', 'snippet': 'Test Heading'}],
            'references': [],
        }
        response = SerpAiResponse.try_parse(json.dumps(data))
        assert response is not None
        assert len(response.text_blocks) == 1
        assert response.text_blocks[0].type == 'heading'
        assert response.text_blocks[0].snippet == 'Test Heading'

    def test_try_parse_paragraph_with_highlights(self) -> None:
        """Parse paragraph with highlighted words."""
        data = {
            'text_blocks': [
                {
                    'type': 'paragraph',
                    'snippet': 'This is important text.',
                    'snippet_highlighted_words': ['important'],
                },
            ],
            'references': [],
        }
        response = SerpAiResponse.try_parse(json.dumps(data))
        assert response is not None
        assert response.text_blocks[0].snippet_highlighted_words == ['important']

    def test_try_parse_references(self) -> None:
        """Parse references correctly."""
        data = {
            'text_blocks': [],
            'references': [
                {
                    'title': 'Wikipedia',
                    'link': 'https://wikipedia.org',
                    'source': 'wikipedia.org',
                    'index': 0,
                },
            ],
        }
        response = SerpAiResponse.try_parse(json.dumps(data))
        assert response is not None
        assert len(response.references) == 1
        assert response.references[0].title == 'Wikipedia'
        assert response.references[0].index == 0


class TestConvertToMarkdown:
    """Tests for convert_to_markdown function."""

    def test_empty_response(self) -> None:
        """Empty response produces minimal output."""
        json_str = '{"text_blocks": [], "references": []}'
        result = convert_to_markdown(json_str)
        assert result == '\n'

    def test_invalid_json_returns_empty(self) -> None:
        """Invalid JSON returns empty string."""
        result = convert_to_markdown('invalid json')
        assert result == ''

    def test_heading_renders_as_h2(self) -> None:
        """Heading block renders as ## heading."""
        data = {
            'text_blocks': [{'type': 'heading', 'snippet': 'My Heading'}],
            'references': [],
        }
        result = convert_to_markdown(json.dumps(data))
        assert '## My Heading' in result

    def test_paragraph_renders_plain(self) -> None:
        """Paragraph renders as plain text."""
        data = {
            'text_blocks': [
                {'type': 'paragraph', 'snippet': 'This is a paragraph.'},
            ],
            'references': [],
        }
        result = convert_to_markdown(json.dumps(data))
        assert 'This is a paragraph.' in result

    def test_paragraph_highlights_as_bold(self) -> None:
        """Highlighted words render as bold."""
        data = {
            'text_blocks': [
                {
                    'type': 'paragraph',
                    'snippet': 'This is important text.',
                    'snippet_highlighted_words': ['important'],
                },
            ],
            'references': [],
        }
        result = convert_to_markdown(json.dumps(data))
        assert '**important**' in result

    def test_list_renders_bullets(self) -> None:
        """List block renders with bullet points."""
        data = {
            'text_blocks': [
                {
                    'type': 'list',
                    'list': [
                        {'snippet': 'First item'},
                        {'snippet': 'Second item'},
                    ],
                },
            ],
            'references': [],
        }
        result = convert_to_markdown(json.dumps(data))
        assert '- First item' in result
        assert '- Second item' in result

    def test_code_block_with_language(self) -> None:
        """Code block renders with language."""
        data = {
            'text_blocks': [
                {
                    'type': 'code_block',
                    'snippet': 'print("hello")',
                    'language': 'python',
                },
            ],
            'references': [],
        }
        result = convert_to_markdown(json.dumps(data))
        assert '```python' in result
        assert 'print("hello")' in result

    def test_table_renders_markdown_table(self) -> None:
        """Table renders as Markdown table."""
        data = {
            'text_blocks': [
                {
                    'type': 'table',
                    'table': [
                        ['Name', 'Value'],
                        ['foo', '123'],
                        ['bar', '456'],
                    ],
                },
            ],
            'references': [],
        }
        result = convert_to_markdown(json.dumps(data))
        assert '| Name | Value |' in result
        assert '| --- | --- |' in result
        assert '| foo | 123 |' in result

    def test_references_render_at_end(self) -> None:
        """References render as numbered list at the end."""
        data = {
            'text_blocks': [{'type': 'paragraph', 'snippet': 'Some text.'}],
            'references': [
                {
                    'title': 'Source One',
                    'link': 'https://example.com/1',
                    'source': 'example.com',
                    'index': 0,
                },
                {
                    'title': 'Source Two',
                    'link': 'https://example.com/2',
                    'index': 1,
                },
            ],
        }
        result = convert_to_markdown(json.dumps(data))
        assert '## Sources' in result
        assert '1. [Source One](https://example.com/1) (example.com)' in result
        assert '2. [Source Two](https://example.com/2)' in result

    def test_expandable_renders_with_title(self) -> None:
        """Expandable block renders with ### heading."""
        data = {
            'text_blocks': [
                {
                    'type': 'expandable',
                    'title': 'Details',
                    'text_blocks': [
                        {'type': 'paragraph', 'snippet': 'Nested content.'},
                    ],
                },
            ],
            'references': [],
        }
        result = convert_to_markdown(json.dumps(data))
        assert '### Details' in result
        assert 'Nested content.' in result

    def test_nested_list(self) -> None:
        """Nested list items are indented properly."""
        data = {
            'text_blocks': [
                {
                    'type': 'list',
                    'list': [
                        {
                            'snippet': 'Parent item',
                            'list': [
                                {'snippet': 'Child item'},
                            ],
                        },
                    ],
                },
            ],
            'references': [],
        }
        result = convert_to_markdown(json.dumps(data))
        assert '- Parent item' in result
        assert '  - Child item' in result

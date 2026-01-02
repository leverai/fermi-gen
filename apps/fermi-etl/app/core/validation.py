"""Validation utilities for the ETL pipeline."""

import re


def validate_seed(seed_text: str) -> str:
    """Validate a preprocessed seed text.

    Args:
        seed_text: The preprocessed seed text to validate

    Returns:
        The validated seed text

    Raises:
        AssertionError: If the seed text is empty, too short, too long, or does not
        contain at least one letter

    """
    assert seed_text, 'Seed text cannot be empty after preprocessing'
    assert len(seed_text) >= 2, 'Seed text must be at least 2 characters long'
    assert len(seed_text) <= 200, 'Seed text cannot exceed 200 characters'
    assert re.search(r'[a-zA-Z]', seed_text), (
        'Seed text must contain at least one letter'
    )
    return seed_text


def validate_question(question_text: str) -> str:
    """Validate a question text.

    Args:
        question_text: The question text to validate

    Returns:
        The validated question text

    Raises:
        AssertionError: If the question text is empty, too short, too long, or does not
        contain at least one letter.

    """
    assert question_text, 'Question text cannot be empty'
    assert len(question_text) >= 10, 'Question text must be at least 10 characters long'
    assert len(question_text) <= 500, 'Question text cannot exceed 500 characters'
    assert re.search(r'[a-zA-Z]', question_text), (
        'Question text must contain at least one letter'
    )
    return question_text

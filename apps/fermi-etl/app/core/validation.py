"""Validation utilities for the ETL pipeline."""

import re


def validate_seed(seed_text: str) -> tuple[bool, str | None]:
    """Validate a preprocessed seed text.

    Args:
        seed_text: The preprocessed seed text to validate

    Returns:
        Tuple of (is_valid, error_message)
        - (True, None) if valid
        - (False, error_message) if invalid

    """
    if not seed_text:
        return False, 'Seed text cannot be empty after preprocessing'

    if len(seed_text) < 2:
        return False, 'Seed text must be at least 2 characters long'

    if len(seed_text) > 200:
        return False, 'Seed text cannot exceed 200 characters'

    # Ensure it contains at least one letter
    if not re.search(r'[a-zA-Z]', seed_text):
        return False, 'Seed text must contain at least one letter'

    return True, None


def validate_question(question_text: str) -> tuple[bool, str | None]:
    """Validate a question text.

    Args:
        question_text: The question text to validate

    Returns:
        Tuple of (is_valid, error_message)
        - (True, None) if valid
        - (False, error_message) if invalid

    """
    if not question_text:
        return False, 'Question text cannot be empty'

    if len(question_text) < 10:
        return False, 'Question text must be at least 10 characters long'

    if len(question_text) > 500:
        return False, 'Question text cannot exceed 500 characters'

    # Ensure it contains at least one letter
    if not re.search(r'[a-zA-Z]', question_text):
        return False, 'Question text must contain at least one letter'

    return True, None

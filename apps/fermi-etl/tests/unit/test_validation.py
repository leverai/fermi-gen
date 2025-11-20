"""Unit tests for validation utilities."""

import pytest

from app.core.validation import validate_question, validate_seed


class TestSeedValidation:
    """Tests for seed validation logic."""

    def test_validate_seed_valid(self) -> None:
        """Test that valid seeds pass validation."""
        valid_seeds = [
            'Machine Learning',
            'AI',
            'Data Science and Analytics',
            'ab',  # Minimum length
            'x' * 200,  # Maximum length
            'Science123',  # Contains numbers
            'Bio-Technology',  # Contains hyphens
        ]

        for seed in valid_seeds:
            is_valid, error = validate_seed(seed)
            assert is_valid is True, f"Seed '{seed}' should be valid"
            assert error is None

    def test_validate_seed_empty(self) -> None:
        """Test that empty seed is rejected."""
        is_valid, error = validate_seed('')
        assert is_valid is False
        assert error
        assert 'cannot be empty' in error.lower()

    def test_validate_seed_too_short(self) -> None:
        """Test that seeds shorter than 2 characters are rejected."""
        is_valid, error = validate_seed('a')
        assert is_valid is False
        assert error
        assert 'at least 2 characters' in error.lower()

    def test_validate_seed_too_long(self) -> None:
        """Test that seeds longer than 200 characters are rejected."""
        long_seed = 'x' * 201
        is_valid, error = validate_seed(long_seed)
        assert is_valid is False
        assert error
        assert 'cannot exceed 200 characters' in error.lower()

    def test_validate_seed_no_letters(self) -> None:
        """Test that seeds with no letters are rejected."""
        invalid_seeds = [
            '123',
            '456789',
            '!!!',
            '---',
        ]

        for seed in invalid_seeds:
            is_valid, error = validate_seed(seed)
            assert is_valid is False, f"Seed '{seed}' should be invalid"
            assert error
            assert 'must contain at least one letter' in error.lower()

    def test_validate_seed_whitespace_only(self) -> None:
        """Test that whitespace-only seeds are rejected."""
        is_valid, error = validate_seed('   ')
        assert is_valid is False
        # Will be rejected for being too short after stripping

    def test_validate_seed_unicode(self) -> None:
        """Test that seeds with unicode characters are valid if they contain letters."""
        is_valid, error = validate_seed('Café')
        assert is_valid is True
        assert error is None


class TestQuestionValidation:
    """Tests for question validation logic."""

    def test_validate_question_valid(self) -> None:
        """Test that valid questions pass validation."""
        valid_questions = [
            'How many trees are in Central Park?',
            'What is the average number of atoms in a human body?',
            'x' * 10,  # Minimum length
            'x' * 500,  # Maximum length
            'How many people live in NYC?',
            "What's the distance to Mars?",
        ]

        for question in valid_questions:
            is_valid, error = validate_question(question)
            assert is_valid is True, f"Question '{question}' should be valid"
            assert error is None

    def test_validate_question_empty(self) -> None:
        """Test that empty question is rejected."""
        is_valid, error = validate_question('')
        assert is_valid is False
        assert error
        assert 'cannot be empty' in error.lower()

    def test_validate_question_too_short(self) -> None:
        """Test that questions shorter than 10 characters are rejected."""
        short_questions = [
            'Short',
            'Hi there',
            'Test',
            'x' * 9,
        ]

        for question in short_questions:
            is_valid, error = validate_question(question)
            assert is_valid is False, f"Question '{question}' should be invalid"
            assert error
            assert 'at least 10 characters' in error.lower()

    def test_validate_question_too_long(self) -> None:
        """Test that questions longer than 500 characters are rejected."""
        long_question = 'x' * 501
        is_valid, error = validate_question(long_question)
        assert is_valid is False
        assert error
        assert 'cannot exceed 500 characters' in error.lower()

    def test_validate_question_no_letters(self) -> None:
        """Test that questions with no letters are rejected."""
        invalid_questions = [
            '1234567890',
            '!!! ??? ###',
            '123-456-7890',
        ]

        for question in invalid_questions:
            is_valid, error = validate_question(question)
            assert is_valid is False, f"Question '{question}' should be invalid"
            assert error
            assert 'must contain at least one letter' in error.lower()

    def test_validate_question_with_numbers(self) -> None:
        """Test that questions with numbers are valid if they contain letters."""
        is_valid, error = validate_question('How many items are in 3 boxes?')
        assert is_valid is True
        assert error is None

    def test_validate_question_with_special_chars(self) -> None:
        """Test that questions with special chars are valid with letters."""
        questions = [
            "What's the population?",
            'How many people (approx.)?',
            'Distance: Earth -> Moon?',
        ]

        for question in questions:
            is_valid, error = validate_question(question)
            assert is_valid is True
            assert error is None

    def test_validate_question_whitespace_only(self) -> None:
        """Test that whitespace-only questions are rejected."""
        is_valid, error = validate_question('          ')
        assert is_valid is False
        # Will be rejected for being too short after stripping

    def test_validate_question_unicode(self) -> None:
        """Test that questions with unicode characters are valid with letters."""
        is_valid, error = validate_question('Combien de personnes vivent à Paris?')
        assert is_valid is True
        assert error is None


@pytest.mark.parametrize(
    ('seed', 'expected_valid'),
    [
        ('Valid Seed', True),
        ('ab', True),
        ('x' * 200, True),
        ('', False),
        ('a', False),
        ('x' * 201, False),
        ('123', False),
    ],
)
def test_validate_seed_parametrized(seed: str, *, expected_valid: bool) -> None:
    """Test seed validation with parametrized inputs."""
    is_valid, error = validate_seed(seed)
    assert is_valid == expected_valid
    if expected_valid:
        assert error is None
    else:
        assert error is not None


@pytest.mark.parametrize(
    ('question', 'expected_valid'),
    [
        ('How many trees in the park?', True),
        ('x' * 10, True),
        ('x' * 500, True),
        ('', False),
        ('Short', False),
        ('x' * 501, False),
        ('1234567890', False),
    ],
)
def test_validate_question_parametrized(question: str, *, expected_valid: bool) -> None:
    """Test question validation with parametrized inputs."""
    is_valid, error = validate_question(question)
    assert is_valid == expected_valid
    if expected_valid:
        assert error is None
    else:
        assert error is not None

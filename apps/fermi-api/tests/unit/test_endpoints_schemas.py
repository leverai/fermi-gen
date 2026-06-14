"""Unit tests for endpoint schemas."""

import pytest
from pydantic import ValidationError

from app.schemas.endpoints import (
    QuestionRoundSettings,
    UpdateUserProfileRequest,
)


def test_update_user_profile_request_valid_display_name() -> None:
    """Test that valid display names are accepted."""
    # Valid display names
    valid_names = [
        'John Doe',
        'user123',
        'user-name',
        "O'Brien",
        'user_name',
        'user.name',
        'User 123',
    ]
    for name in valid_names:
        request = UpdateUserProfileRequest(display_name=name)
        assert request.display_name == name.strip()


def test_update_user_profile_request_invalid_display_name() -> None:
    """Test that invalid display names are rejected."""
    # Invalid display names (containing special characters)
    invalid_names = [
        '<script>alert("xss")</script>',
        'user@example.com',
        'user#123',
        'user$money',
        'user%percent',
        'user&and',
        'user*star',
        'user+plus',
        'user=equals',
        'user|pipe',
        'user\\backslash',
        'user/forward',
        'user?question',
        'user!exclamation',
    ]
    for name in invalid_names:
        with pytest.raises(ValidationError) as exc_info:
            UpdateUserProfileRequest(display_name=name)
        assert 'invalid characters' in str(exc_info.value).lower()


def test_update_user_profile_request_display_name_max_length() -> None:
    """Test that display names exceeding max length are rejected."""
    long_name = 'a' * 51  # 51 characters, max is 50
    with pytest.raises(ValidationError) as exc_info:
        UpdateUserProfileRequest(display_name=long_name)
    assert 'at most 50' in str(exc_info.value).lower()


def test_update_user_profile_request_valid_avatar_url() -> None:
    """Test that valid avatar URLs are accepted."""
    # Valid avatar URLs
    valid_urls = [
        '/static/avatars/avatar1.svg',
        'https://example.com/avatar.png',
        'https://lh3.googleusercontent.com/a/avatar',
        'http://localhost:8000/static/avatars/test.svg',
    ]
    for url in valid_urls:
        request = UpdateUserProfileRequest(avatar_url=url)
        assert request.avatar_url == url


def test_update_user_profile_request_invalid_avatar_url() -> None:
    """Test that invalid avatar URLs are rejected."""
    # Invalid avatar URLs
    invalid_urls = [
        'http://example.com/avatar.png',  # HTTP not allowed (except localhost)
        'ftp://example.com/avatar.png',
        'javascript:alert("xss")',
        'file:///etc/passwd',
        '//example.com/avatar.png',  # Protocol-relative URL
        'data:image/png;base64,iVBORw0KGgo...',  # Data URL
    ]
    for url in invalid_urls:
        with pytest.raises(ValidationError) as exc_info:
            UpdateUserProfileRequest(avatar_url=url)
        assert 'internal asset or valid HTTPS URL' in str(exc_info.value)


def test_update_user_profile_request_avatar_url_max_length() -> None:
    """Test that avatar URLs exceeding max length are rejected."""
    long_url = 'https://example.com/' + 'a' * 500  # Exceeds 500 char limit
    with pytest.raises(ValidationError) as exc_info:
        UpdateUserProfileRequest(avatar_url=long_url)
    assert 'at most 500' in str(exc_info.value).lower()


def test_update_user_profile_request_none_values() -> None:
    """Test that None values are allowed."""
    request = UpdateUserProfileRequest(display_name=None, avatar_url=None)
    assert request.display_name is None
    assert request.avatar_url is None


def test_update_user_profile_request_display_name_stripped() -> None:
    """Test that display names are stripped of whitespace."""
    request = UpdateUserProfileRequest(display_name='  John Doe  ')
    assert request.display_name == 'John Doe'


def test_question_round_settings_search_query_default_none() -> None:
    """search_query defaults to None (no search)."""
    qrs = QuestionRoundSettings(difficulty=None)
    assert qrs.search_query is None


def test_question_round_settings_search_query_trimmed() -> None:
    """A valid search query is trimmed of surrounding whitespace."""
    qrs = QuestionRoundSettings(difficulty=None, search_query='  space scale  ')
    assert qrs.search_query == 'space scale'


def test_question_round_settings_search_query_all_whitespace_is_none() -> None:
    """An all-whitespace query trims to empty and is treated as no search."""
    qrs = QuestionRoundSettings(difficulty=None, search_query='    ')
    assert qrs.search_query is None


def test_question_round_settings_search_query_too_short_rejected() -> None:
    """A 1-char (post-trim) query is rejected (min length 2)."""
    with pytest.raises(ValidationError) as exc_info:
        QuestionRoundSettings(difficulty=None, search_query='a')
    assert 'between 2 and 100' in str(exc_info.value)


def test_question_round_settings_search_query_too_long_rejected() -> None:
    """A 101-char query is rejected (max length 100)."""
    with pytest.raises(ValidationError) as exc_info:
        QuestionRoundSettings(difficulty=None, search_query='x' * 101)
    assert 'between 2 and 100' in str(exc_info.value)


def test_question_round_settings_search_query_boundaries_accepted() -> None:
    """Exactly 2 and exactly 100 chars are both accepted."""
    assert (
        QuestionRoundSettings(
            difficulty=None,
            search_query='ab',
        ).search_query
        == 'ab'
    )
    long_query = 'x' * 100
    assert (
        QuestionRoundSettings(
            difficulty=None,
            search_query=long_query,
        ).search_query
        == long_query
    )

"""Integration tests for Daily Question Post-Take endpoints.

Tests verify endpoint routing, auth, and error handling for the post-take flow.
Post-take allows users to take older closed DQs they haven't participated in.
"""

from collections.abc import Callable
from datetime import datetime

from fastapi.testclient import TestClient


def test_post_take_start_returns_404_for_nonexistent_date(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """POST /post_take/{date}/start returns 404 for non-existent DQ."""
    headers = get_api_auth_headers(
        'post-take-404@example.com',
        'password123',
        'PostTake404User',
    )

    # Use a date far in the past that won't have a DQ
    resp = api_client.post(
        '/api/v1/daily_question/post_take/2020-01-01/start',
        headers=headers,
    )

    assert resp.status_code == 404
    assert 'No daily question found' in resp.json().get('detail', '')


def test_post_take_answer_returns_404_for_nonexistent_date(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """POST /post_take/{date}/answer returns 404 for non-existent DQ."""
    headers = get_api_auth_headers(
        'post-take-answer-404@example.com',
        'password123',
        'PostTakeAnswer404',
    )

    resp = api_client.post(
        '/api/v1/daily_question/post_take/2020-01-01/answer',
        json={
            'answer': {'number': 42, 'unit': None},
            'started_at': datetime.utcnow().isoformat() + 'Z',  # noqa: DTZ003
        },
        headers=headers,
    )

    assert resp.status_code == 404
    assert 'No daily question found' in resp.json().get('detail', '')


def test_post_take_answer_validates_started_at_format(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """POST /post_take/{date}/answer validates started_at is valid datetime."""
    headers = get_api_auth_headers(
        'post-take-invalid-dt@example.com',
        'password123',
        'PostTakeInvalidDT',
    )

    resp = api_client.post(
        '/api/v1/daily_question/post_take/2020-01-01/answer',
        json={
            'answer': {'number': 42, 'unit': None},
            'started_at': 'not-a-datetime',
        },
        headers=headers,
    )

    # Should fail validation for invalid datetime format
    assert resp.status_code == 422


def test_post_take_start_validates_date_format(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """POST /post_take/{date}/start validates date format."""
    headers = get_api_auth_headers(
        'post-take-bad-date@example.com',
        'password123',
        'PostTakeBadDate',
    )

    # Invalid date format
    resp = api_client.post(
        '/api/v1/daily_question/post_take/2020-1-1/start',  # Should be 2020-01-01
        headers=headers,
    )

    # Path pattern validation should reject this
    assert resp.status_code == 422

"""Integration tests for Daily Question Post-Take endpoints.

Tests verify endpoint routing, auth, and error handling for the post-take flow.
Post-take allows Pro users to take older closed DQs they haven't participated in.
"""

from collections.abc import Callable
from datetime import datetime

from fastapi.testclient import TestClient

# --- Tier Gating Tests ---


def test_post_take_start_requires_pro_subscription(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """POST /post_take/{date}/start returns 403 for free users."""
    headers = get_api_auth_headers(
        'free-user-posttake@example.com',
        'password123',
        'FreeUserPostTake',
    )

    resp = api_client.post(
        '/api/v1/daily_question/post_take/2020-01-01/start',
        headers=headers,
    )

    assert resp.status_code == 403
    assert 'Pro subscription' in resp.json().get('detail', '')


def test_post_take_answer_requires_pro_subscription(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """POST /post_take/{date}/answer returns 403 for free users."""
    headers = get_api_auth_headers(
        'free-user-answer@example.com',
        'password123',
        'FreeUserAnswer',
    )

    resp = api_client.post(
        '/api/v1/daily_question/post_take/2020-01-01/answer',
        json={
            'answer': {'number': 42, 'unit': None},
            'started_at': datetime.utcnow().isoformat() + 'Z',  # noqa: DTZ003
        },
        headers=headers,
    )

    assert resp.status_code == 403
    assert 'Pro subscription' in resp.json().get('detail', '')


def test_post_take_start_with_ad_bypasses_pro_check(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """POST /post_take/{date}/start with with_ad=true bypasses Pro check for FREE users.

    When with_ad=true, the endpoint should skip the Pro subscription check
    and proceed to check if the DQ exists (404 instead of 403).
    """
    headers = get_api_auth_headers(
        'free-user-posttake-ad@example.com',
        'password123',
        'FreeUserPostTakeAd',
    )

    resp = api_client.post(
        '/api/v1/daily_question/post_take/2020-01-01/start?with_ad=true',
        headers=headers,
    )

    # Should get 404 (DQ not found) instead of 403 (Pro required)
    assert resp.status_code == 404
    assert 'No daily question found' in resp.json().get('detail', '')


def test_post_take_answer_with_ad_bypasses_pro_check(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """POST /post_take/{date}/answer with with_ad=true bypasses Pro check."""
    headers = get_api_auth_headers(
        'free-user-answer-ad@example.com',
        'password123',
        'FreeUserAnswerAd',
    )

    resp = api_client.post(
        '/api/v1/daily_question/post_take/2020-01-01/answer?with_ad=true',
        json={
            'answer': {'number': 42, 'unit': None},
            'started_at': datetime.utcnow().isoformat() + 'Z',  # noqa: DTZ003
        },
        headers=headers,
    )

    # Should get 404 (DQ not found) instead of 403 (Pro required)
    assert resp.status_code == 404
    assert 'No daily question found' in resp.json().get('detail', '')


# --- Pro User Tests (existing tests updated to use Pro fixture) ---


def test_post_take_start_returns_404_for_nonexistent_date(
    api_client: TestClient,
    get_pro_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """POST /post_take/{date}/start returns 404 for non-existent DQ (Pro user)."""
    headers = get_pro_api_auth_headers(
        'pro-post-take-404@example.com',
        'password123',
        'ProPostTake404User',
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
    get_pro_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """POST /post_take/{date}/answer returns 404 for non-existent DQ (Pro user)."""
    headers = get_pro_api_auth_headers(
        'pro-post-take-answer-404@example.com',
        'password123',
        'ProPostTakeAnswer404',
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
    get_pro_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """POST /post_take/{date}/answer validates started_at is valid datetime."""
    headers = get_pro_api_auth_headers(
        'pro-post-take-invalid-dt@example.com',
        'password123',
        'ProPostTakeInvalidDT',
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
    """POST /post_take/{date}/start validates date format.

    Note: This uses free user because path validation happens before tier check.
    """
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

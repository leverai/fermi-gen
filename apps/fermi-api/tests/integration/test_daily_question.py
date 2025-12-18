"""Integration tests for Daily Question endpoints.

These tests verify endpoint routing, auth, and basic response format.
Full start→answer→results flow requires seeding ACTIVE DQ data.
"""

from collections.abc import Callable
from typing import Any

from fastapi.testclient import TestClient


def test_start_returns_404_when_no_dq_available(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """POST /daily_question/start returns 404 when no DQ exists."""
    headers = get_api_auth_headers(
        'dq-test-user@example.com',
        'password123',
        'DQTestUser',
    )

    resp = api_client.post('/api/v1/daily_question/start', headers=headers)

    # Should be 404 (no DQ) or 409 (window closed) depending on timing
    assert resp.status_code in (404, 409)


def test_archive_week_returns_valid_response(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """GET /daily_question/archive/week returns valid structure."""
    headers = get_api_auth_headers(
        'dq-archive-user@example.com',
        'password123',
        'ArchiveUser',
    )

    resp = api_client.get('/api/v1/daily_question/archive/week', headers=headers)

    assert resp.status_code == 200
    data = resp.json()
    assert 'items' in data
    assert 'today' in data
    assert isinstance(data['items'], dict)
    # today should be YYYY-MM-DD format
    assert len(data['today']) == 10
    assert data['today'][4] == '-'


def test_archive_month_returns_valid_response(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """GET /daily_question/archive/month returns valid structure."""
    headers = get_api_auth_headers(
        'dq-month-user@example.com',
        'password123',
        'MonthUser',
    )

    resp = api_client.get(
        '/api/v1/daily_question/archive/month',
        params={'year': 2024, 'month': 12},
        headers=headers,
    )

    assert resp.status_code == 200
    data = resp.json()
    assert 'items' in data
    assert 'today' in data
    assert isinstance(data['items'], dict)


def test_archive_month_validates_month_range(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """GET /daily_question/archive/month rejects invalid month."""
    headers = get_api_auth_headers(
        'dq-month-invalid@example.com',
        'password123',
        'MonthInvalid',
    )

    resp = api_client.get(
        '/api/v1/daily_question/archive/month',
        params={'year': 2024, 'month': 13},  # Invalid month
        headers=headers,
    )

    assert resp.status_code == 422  # Validation error


def test_results_returns_404_for_nonexistent_date(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """GET /daily_question/results/{date} returns 404 for nonexistent DQ."""
    headers = get_api_auth_headers(
        'dq-results-user@example.com',
        'password123',
        'ResultsUser',
    )

    resp = api_client.get(
        '/api/v1/daily_question/results/2020-01-01',
        headers=headers,
    )

    assert resp.status_code == 404


def test_answer_returns_409_without_starting(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """POST /daily_question/answer returns 409 when user hasn't started."""
    headers = get_api_auth_headers(
        'dq-answer-user@example.com',
        'password123',
        'AnswerUser',
    )

    resp = api_client.post(
        '/api/v1/daily_question/answer',
        json={'answer': {'number': 42, 'unit': None}},
        headers=headers,
    )

    # Should be 404 (no DQ) or 409 (must start first)
    assert resp.status_code in (404, 409)

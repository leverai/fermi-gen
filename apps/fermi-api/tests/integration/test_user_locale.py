"""Integration test for POST /user/set_locale."""

from __future__ import annotations

from collections.abc import Callable

from fastapi.testclient import TestClient


def test_set_locale_returns_200(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Setting user locale should return literal 200."""
    headers = get_api_auth_headers(
        'dev.user+locale@example.com',
        'password123',
        'LocaleUser',
    )
    r = api_client.post(
        '/api/v1/user/set_locale',
        json={'locale': 'US'},
        headers=headers,
    )
    assert r.status_code == 200
    assert r.json() == 200

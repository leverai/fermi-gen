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


def test_locale_persists_in_auth_responses(
    api_client: TestClient,
    create_emulator_user_and_get_token: Callable[[str, str, str], dict],
) -> None:
    """Locale should be included in token exchange and refresh responses.
    
    This test ensures the locale field is always present in UserResponse
    and persists correctly across authentication flows.
    """
    # 1. Create user and get initial Firebase token
    email = 'locale.persist@example.com'
    creds = create_emulator_user_and_get_token(email, 'password123', 'LocalePersist')
    firebase_token = creds['idToken']
    
    # 2. Exchange Firebase token for access token
    token_resp = api_client.post(
        '/api/v1/auth/token',
        headers={'Authorization': f'Bearer {firebase_token}'},
    )
    assert token_resp.status_code == 200
    token_data = token_resp.json()
    
    # Verify locale field is present (should default to 'US')
    assert 'user' in token_data
    assert 'locale' in token_data['user']
    assert token_data['user']['locale'] == 'US'
    
    access_token = token_data['access_token']
    
    # 3. Set locale to EU
    set_locale_resp = api_client.post(
        '/api/v1/user/set_locale',
        json={'locale': 'EU'},
        headers={'Authorization': f'Bearer {access_token}'},
    )
    assert set_locale_resp.status_code == 200
    
    # 4. Refresh token and verify locale persists
    refresh_resp = api_client.post(
        '/api/v1/auth/refresh',
        headers={'Authorization': f'Bearer {access_token}'},
    )
    assert refresh_resp.status_code == 200
    refresh_data = refresh_resp.json()
    
    # Verify locale field is present and set to EU
    assert 'user' in refresh_data
    assert 'locale' in refresh_data['user']
    assert refresh_data['user']['locale'] == 'EU'
    
    # 5. Exchange Firebase token again (simulating app restart)
    # This simulates the user closing and reopening the app
    new_token_resp = api_client.post(
        '/api/v1/auth/token',
        headers={'Authorization': f'Bearer {firebase_token}'},
    )
    assert new_token_resp.status_code == 200
    new_token_data = new_token_resp.json()
    
    # Verify locale still persists as EU
    assert 'user' in new_token_data
    assert 'locale' in new_token_data['user']
    assert new_token_data['user']['locale'] == 'EU'


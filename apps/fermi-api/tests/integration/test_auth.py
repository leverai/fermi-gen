"""Integration tests for authentication and protected routes.

Requires running Firebase Auth emulator and (optionally) Postgres if app startup
touches the DB. See README for emulator startup commands.
"""

from collections.abc import Callable

from fastapi.testclient import TestClient


def test_token_exchange_with_valid_emulator_token(
    api_client: TestClient,
    create_emulator_user_and_get_token: Callable[[str, str, str], dict],
) -> None:
    """Valid emulator token should exchange to access token and user payload."""
    email = 'dev.user@example.com'
    creds = create_emulator_user_and_get_token(email, 'password123', 'Dev Valid')
    firebase_token = creds['idToken']
    resp = api_client.post(
        '/api/v1/auth/token',
        headers={'Authorization': f'Bearer {firebase_token}'},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert 'access_token' in data
    assert 'user' in data
    assert data['user']['firebase_uid']


def test_token_exchange_with_invalid_token_returns_401(api_client: TestClient) -> None:
    """Invalid token should return 401 from /auth/token."""
    resp = api_client.post(
        '/api/v1/auth/token',
        headers={'Authorization': 'Bearer invalid.token.here'},
    )
    assert resp.status_code == 401


def test_protected_route_without_token_returns_401(api_client: TestClient) -> None:
    """Protected route should require Authorization header and return 401 otherwise."""
    resp = api_client.get('/api/v1/game/config')
    assert resp.status_code == 401


def test_refresh_returns_new_access_token(
    api_client: TestClient,
    create_emulator_user_and_get_token: Callable[[str, str, str], dict],
) -> None:
    """Refresh endpoint should mint a new token from a valid access token."""
    # Exchange a Firebase token for an access token first
    email = 'refresh.user@example.com'
    creds = create_emulator_user_and_get_token(email, 'password123', 'Refresh User')
    firebase_token = creds['idToken']
    resp = api_client.post(
        '/api/v1/auth/token',
        headers={'Authorization': f'Bearer {firebase_token}'},
    )
    assert resp.status_code == 200
    access_token = resp.json()['access_token']

    # Call refresh with the existing access token
    refresh_resp = api_client.post(
        '/api/v1/auth/refresh',
        headers={'Authorization': f'Bearer {access_token}'},
    )
    assert refresh_resp.status_code == 200
    new_token = refresh_resp.json()['access_token']
    assert isinstance(new_token, str)
    assert new_token

    # New token should access a protected route
    cfg_resp = api_client.get(
        '/api/v1/game/config',
        headers={'Authorization': f'Bearer {new_token}'},
    )
    assert cfg_resp.status_code == 200

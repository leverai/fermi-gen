"""API-only validation tests for POST /game/create.

Uses a lightweight app with dependency overrides to avoid DB/emulator.
"""

from fastapi.testclient import TestClient

from app.core.config import settings


def test_create_game_missing_body_returns_422_api_only(
    client_overrides: TestClient,
) -> None:
    """Missing body should 422 without invoking heavy dependencies."""
    resp = client_overrides.post(f'{settings.api_v1_str}/game/create', json={})
    assert resp.status_code == 422

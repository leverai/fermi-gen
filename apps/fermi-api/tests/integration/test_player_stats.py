"""Integration test for POST /game/get_player_stats."""

from __future__ import annotations

from collections.abc import Callable

from fastapi.testclient import TestClient


def test_get_player_stats_shape(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Stats endpoint should return simplified stats structure."""
    headers = get_api_auth_headers(
        'dev.user+stats@example.com',
        'password123',
        'StatsUser',
    )
    # Note: API contract uses a string player_id. For this smoke test we pass a
    # placeholder string; backend should handle lookup/shape.
    payload = {'player_id': 'dev.user+stats@example.com'}
    r = api_client.post(
        '/api/v1/game/get_player_stats',
        json=payload,
        headers=headers,
    )
    assert r.status_code == 200
    body = r.json()
    assert 'player_id' in body
    assert body['player_id']
    assert 'stats' in body
    stats = body['stats']
    assert isinstance(stats, dict)
    assert 'total_party_games' in stats
    assert isinstance(stats['total_party_games'], int)
    assert 'total_daily_guesses' in stats
    assert isinstance(stats['total_daily_guesses'], int)
    assert 'average_percentile' in stats
    assert isinstance(stats['average_percentile'], int)
    assert 'level' in stats
    assert stats['level'] == 1  # Level is not yet implemented

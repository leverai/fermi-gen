"""Integration test for POST /game/get_player_stats."""

from __future__ import annotations

from collections.abc import Callable

from fastapi.testclient import TestClient


def test_get_player_stats_shape(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Stats endpoint should return player_quantiles structure per README."""
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
    assert isinstance(body['stats'], dict)
    pq = body['stats'].get('player_quantiles')
    assert isinstance(pq, dict)
    assert 'overall' in pq
    assert 'by_category' in pq
    assert isinstance(pq['by_category'], list)
    assert 'by_category_and_difficulty' in pq
    assert isinstance(pq['by_category_and_difficulty'], list)
    assert 'by_difficulty' in pq
    assert isinstance(pq['by_difficulty'], list)

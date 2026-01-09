"""Integration tests for game limits."""

from collections.abc import Callable

from fastapi.testclient import TestClient


def test_free_user_hosting_limit(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Verify free users are limited to 2 games per week."""
    headers = get_api_auth_headers(
        'free.limit@example.com',
        'password123',
        'Free Limit',
    )

    # 1st game
    resp = api_client.post(
        '/api/v1/game/create',
        json={'question_round_settings': {'n_questions': 3, 'difficulty': None}},
        headers=headers,
    )
    assert resp.status_code == 200, f'1st game failed: {resp.text}'
    resp = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': resp.json()['resource_id']},
        headers=headers,
    )
    assert resp.status_code == 200, f'1st game start failed: {resp.text}'

    # 2nd game
    resp = api_client.post(
        '/api/v1/game/create',
        json={'question_round_settings': {'n_questions': 3, 'difficulty': None}},
        headers=headers,
    )
    assert resp.status_code == 200, f'2nd game failed: {resp.text}'
    resp = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': resp.json()['resource_id']},
        headers=headers,
    )
    assert resp.status_code == 200, f'2nd game start failed: {resp.text}'

    # 3rd game (Blocked)
    resp = api_client.post(
        '/api/v1/game/create',
        json={'question_round_settings': {'n_questions': 3, 'difficulty': None}},
        headers=headers,
    )
    assert resp.status_code == 403, f'3rd game start should be forbidden: {resp.text}'
    assert 'Weekly party hosting limit reached' in resp.json()['detail']


def test_pro_user_unlimited_hosting(
    api_client: TestClient,
    get_pro_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Verify pro users have unlimited hosting."""
    headers = get_pro_api_auth_headers(
        'pro.limit@example.com',
        'password123',
        'Pro Limit',
    )

    # Create 3 games (exceeding free limit)
    for i in range(3):
        resp = api_client.post(
            '/api/v1/game/create',
            json={'question_round_settings': {'n_questions': 3, 'difficulty': None}},
            headers=headers,
        )
        assert resp.status_code == 200, f'Game {i + 1} failed for Pro user: {resp.text}'

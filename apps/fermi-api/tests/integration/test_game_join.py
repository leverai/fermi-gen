"""Integration tests for POST /game/join (join by id)."""

from __future__ import annotations

import time
from collections.abc import Callable

from fastapi.testclient import TestClient


def test_join_existing_lobby_game_adds_player(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict],
) -> None:
    """Join by id adds the player while keeping the lobby ready.

    Questions are fetched at start time, so a join must not fetch or clear
    questions.

    Asserts:
    - state stays LOBBY_READY (2)
    - no question_uids are populated (questions are fetched at start)
    - players count increases by 1, host remains unchanged
    """
    host_headers = get_api_auth_headers(
        'dev.user+host@example.com',
        'password123',
        'Host',
    )
    game_id = create_private_game(host_headers)

    # Lobby is ready immediately after create.
    for _ in range(60):
        if get_firestore_doc(game_id).get('state') == 2:
            break
        time.sleep(0.1)
    before_doc = get_firestore_doc(game_id)
    assert before_doc.get('state') == 2
    before_players_n = len(before_doc['players'])
    host_id = before_doc['host']

    # Second user joins by id
    joiner_headers = get_api_auth_headers(
        'dev.user+joiner@example.com',
        'password123',
        'Joiner',
    )
    resp = api_client.post(
        '/api/v1/game/join',
        json={'resource_id': game_id},
        headers=joiner_headers,
    )
    assert resp.status_code == 200

    # Wait until the new player is reflected.
    for _ in range(60):
        if len(get_firestore_doc(game_id).get('players', {})) == before_players_n + 1:
            break
        time.sleep(0.1)

    final_doc = get_firestore_doc(game_id)
    # Lobby stays ready; joining does not reset readiness or fetch questions.
    assert final_doc.get('state') == 2
    assert not final_doc.get('question_uids'), 'join must not fetch questions'
    assert len(final_doc['players']) == before_players_n + 1
    assert final_doc['host'] == host_id


def test_join_nonexistent_game_returns_404(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Join nonexistent game should return 404."""
    headers = get_api_auth_headers(
        'dev.user+noexist@example.com',
        'password123',
        'NoExist',
    )
    resp = api_client.post(
        '/api/v1/game/join',
        json={'resource_id': 'does-not-exist'},
        headers=headers,
    )
    assert resp.status_code == 404

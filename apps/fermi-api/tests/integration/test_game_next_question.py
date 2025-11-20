"""Integration tests for POST /game/next_question (host-only)."""

from __future__ import annotations

import time
from collections.abc import Callable
from typing import Any

from fastapi.testclient import TestClient


def _wait_ready_with_questions(
    get_firestore_doc: Callable[[str], dict[str, Any]],
    game_id: str,
) -> list[str]:
    deadline = time.time() + 6.0
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc and doc.get('state') == 2 and doc.get('question_uids'):
            return [str(u) for u in doc['question_uids']]
        time.sleep(0.1)
    raise AssertionError('Game not ready with questions in time')


def _wait_state(
    get_firestore_doc: Callable[[str], dict[str, Any]],
    game_id: str,
    desired: set[int],
) -> dict[str, Any]:
    deadline = time.time() + 6.0
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc and doc.get('state') in desired:
            return doc
        time.sleep(0.1)
    raise AssertionError('Desired state not reached in time')


def _create_two_player_started_game(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> tuple[str, dict[str, str], dict[str, str]]:
    host_headers = get_api_auth_headers(
        'dev.user+next-host@example.com',
        'password123',
        'NextHost',
    )
    game_id = create_private_game(host_headers)
    _ = _wait_ready_with_questions(get_firestore_doc, game_id)

    joiner_headers = get_api_auth_headers(
        'dev.user+next-joiner@example.com',
        'password123',
        'NextJoiner',
    )
    rj = api_client.post(
        '/api/v1/game/join',
        json={'resource_id': game_id},
        headers=joiner_headers,
    )
    assert rj.status_code == 200
    _ = _wait_ready_with_questions(get_firestore_doc, game_id)

    rs = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert rs.status_code == 200
    _ = _wait_state(get_firestore_doc, game_id, {3, 5})
    return game_id, host_headers, joiner_headers


def test_next_question_happy_path_advances_and_reinits_progress(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Host moves to next question: order increments, uid changes, progress resets."""
    game_id, host_headers, joiner_headers = _create_two_player_started_game(
        api_client,
        get_api_auth_headers,
        create_private_game,
        get_firestore_doc,
    )
    d0 = get_firestore_doc(game_id)
    curr_uid = d0['question_uid']
    curr_order = d0['question_order']

    # Submit answers from both players to reach *_FINISHED
    rh = api_client.post(
        '/api/v1/game/answer',
        json={'resource_id': game_id, 'answer': {'number': 1, 'unit': None}},
        headers=host_headers,
    )
    assert rh.status_code == 200
    rj = api_client.post(
        '/api/v1/game/answer',
        json={'resource_id': game_id, 'answer': {'number': 2, 'unit': None}},
        headers=joiner_headers,
    )
    assert rj.status_code == 200
    _ = _wait_state(get_firestore_doc, game_id, {4, 6})

    # Deactivate the non-host player to verify progress reinit uses only active players
    d_finished = get_firestore_doc(game_id)
    host_id = d_finished['host']
    players_map = d_finished['players']
    joiner_id = next(uid for uid in players_map.keys() if uid != host_id)
    rrem = api_client.post(
        '/api/v1/game/remove_player',
        json={'resource_id': game_id, 'player_id': joiner_id},
        headers=host_headers,
    )
    assert rrem.status_code == 200

    rn = api_client.post(
        '/api/v1/game/next_question',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert rn.status_code == 200

    d1 = _wait_state(get_firestore_doc, game_id, {3, 5})
    assert d1['question_order'] == curr_order + 1
    assert d1['question_uid'] != curr_uid
    # Progress should be reinitialized (answered all False) and include only active
    # players
    answered = d1['progress']['answered']
    assert isinstance(answered, dict)
    assert set(answered.keys()) == {host_id}
    assert all(v is False for v in answered.values())


def test_next_question_non_host_returns_403(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Non-host attempting to advance should get 403."""
    game_id, host_headers, joiner_headers = _create_two_player_started_game(
        api_client,
        get_api_auth_headers,
        create_private_game,
        get_firestore_doc,
    )
    r = api_client.post(
        '/api/v1/game/next_question',
        json={'resource_id': game_id},
        headers=joiner_headers,
    )
    assert r.status_code == 403


def test_next_question_invalid_state_returns_409(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Advancing when question not finished should return 409."""
    game_id, host_headers, _ = _create_two_player_started_game(
        api_client,
        get_api_auth_headers,
        create_private_game,
        get_firestore_doc,
    )
    # Immediately call next_question without finishing
    r = api_client.post(
        '/api/v1/game/next_question',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert r.status_code == 409

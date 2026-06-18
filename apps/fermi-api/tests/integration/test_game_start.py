"""Integration tests for POST /game/start (host-only).

Questions are fetched synchronously when the host starts the game, so after a
``create`` the lobby is ``LOBBY_READY`` with no questions, and after ``start``
the question subcollections are populated and the first question is revealed.
"""

import time
from collections.abc import Callable
from typing import Any

from fastapi.testclient import TestClient


def _wait_ready(
    get_firestore_doc: Callable[[str], dict[str, Any]],
    game_id: str,
    *,
    timeout_s: float = 6.0,
    interval_s: float = 0.1,
) -> dict[str, Any]:
    """Poll until the game is LOBBY_READY (state == 2). Returns the doc."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc and doc.get('state') == 2:
            return doc
        time.sleep(interval_s)
    raise AssertionError('Game did not become LOBBY_READY in time')


def test_start_game_by_host_fetches_questions_reveals_first_and_inits_progress(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Host starts: questions get fetched, first revealed, progress inited."""
    host_headers = get_api_auth_headers(
        'dev.user+start-host@example.com',
        'password123',
        'StartHost',
    )
    game_id = create_private_game(host_headers)
    _wait_ready(get_firestore_doc, game_id)

    # Start the game (questions are fetched synchronously here)
    r = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert r.status_code == 200

    # Poll for state transition and fields
    for _ in range(60):
        doc = get_firestore_doc(game_id)
        state = doc.get('state')
        if state in (3, 5):  # QUESTION_N or QUESTION_LAST
            # questions were populated at start
            question_uids = [str(u) for u in (doc.get('question_uids') or [])]
            assert question_uids, 'question_uids should be populated at start'
            # started_at should be present (timestamp string)
            assert 'started_at' in doc
            # current question fields point at the first question
            assert doc.get('question_uid') == question_uids[0]
            assert doc.get('question_order') == 1
            # Progress initialized
            progress = doc.get('progress') or {}
            answered = progress.get('answered') or {}
            assert isinstance(answered, dict)
            assert all(v is False for v in answered.values())
            assert progress.get('all_answered') is False
            break
        time.sleep(0.1)
    else:
        raise AssertionError('Game state did not transition to a question state')


def test_start_game_by_non_host_returns_403(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Non-host attempting to start should be forbidden (403)."""
    host_headers = get_api_auth_headers(
        'dev.user+start-host2@example.com',
        'password123',
        'StartHost2',
    )
    game_id = create_private_game(host_headers)
    _wait_ready(get_firestore_doc, game_id)

    non_host_headers = get_api_auth_headers(
        'dev.user+start-nonhost@example.com',
        'password123',
        'StartNonHost',
    )
    r = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=non_host_headers,
    )
    assert r.status_code == 403


def test_start_game_second_time_returns_409_not_ready(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Starting again when state != LOBBY_READY should return 409."""
    host_headers = get_api_auth_headers(
        'dev.user+start-twice@example.com',
        'password123',
        'StartTwice',
    )
    game_id = create_private_game(host_headers)
    _wait_ready(get_firestore_doc, game_id)

    r1 = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert r1.status_code == 200

    r2 = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert r2.status_code == 409

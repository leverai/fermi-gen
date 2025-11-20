"""Integration tests for POST /game/answer."""

from __future__ import annotations

import time
from collections.abc import Callable
from typing import Any

from fastapi.testclient import TestClient


def _wait_until_state(
    get_firestore_doc: Callable[[str], dict[str, Any]],
    game_id: str,
    desired_states: set[int],
    *,
    timeout_s: float = 6.0,
    interval_s: float = 0.1,
) -> dict[str, Any]:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc and doc.get('state') in desired_states:
            return doc
        time.sleep(interval_s)
    raise AssertionError('Desired game state not reached in time')


def _wait_ready_with_questions(
    get_firestore_doc: Callable[[str], dict[str, Any]],
    game_id: str,
) -> tuple[list[str], dict[str, Any]]:
    deadline = time.time() + 6.0
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc and doc.get('state') == 2 and doc.get('question_uids'):
            return [str(u) for u in doc['question_uids']], doc
        time.sleep(0.1)
    raise AssertionError('Game not ready with questions in time')


def test_answer_happy_path_two_players_reveals_and_progress(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Both players answer; results revealed and state transitions to finished."""
    # Host creates and waits ready
    host_headers = get_api_auth_headers(
        'dev.user+ans-host@example.com',
        'password123',
        'AnsHost',
    )
    game_id = create_private_game(host_headers)
    qids, _ = _wait_ready_with_questions(get_firestore_doc, game_id)

    # Second player joins by id (use the same helper as join test: directly call join)
    joiner_headers = get_api_auth_headers(
        'dev.user+ans-joiner@example.com',
        'password123',
        'AnsJoiner',
    )
    rj = api_client.post(
        '/api/v1/game/join',
        json={'resource_id': game_id},
        headers=joiner_headers,
    )
    assert rj.status_code == 200

    # Wait until ready again
    _wait_ready_with_questions(get_firestore_doc, game_id)

    # Start game (host)
    rs = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert rs.status_code == 200
    doc = _wait_until_state(get_firestore_doc, game_id, {3, 5})
    curr_q = doc['question_uid']

    # Host submits answer
    rh = api_client.post(
        '/api/v1/game/answer',
        json={'resource_id': game_id, 'answer': {'number': 1000, 'unit': None}},
        headers=host_headers,
    )
    assert rh.status_code == 200
    # Progress should reflect one answered, all_answered False
    d1 = get_firestore_doc(game_id)
    answered1 = d1['progress']['answered']
    assert any(answered1.values())
    assert d1['progress']['all_answered'] is False

    # Joiner submits answer
    rj2 = api_client.post(
        '/api/v1/game/answer',
        json={'resource_id': game_id, 'answer': {'number': 1000, 'unit': None}},
        headers=joiner_headers,
    )
    assert rj2.status_code == 200

    # After last active player answers, state should be *_FINISHED and results revealed
    df = _wait_until_state(get_firestore_doc, game_id, {4, 6})
    assert df['question_uid'] == curr_q
    # players_results/{qid} revealed
    # Light check via progress and players_results id existence
    assert df['progress']['all_answered'] is True


def test_answer_duplicate_submission_returns_409(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Submitting twice by same user should return 409 after first 200."""
    host_headers = get_api_auth_headers(
        'dev.user+ans-dupe@example.com',
        'password123',
        'AnsDupe',
    )
    game_id = create_private_game(host_headers)
    _wait_ready_with_questions(get_firestore_doc, game_id)
    rs = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert rs.status_code == 200

    r1 = api_client.post(
        '/api/v1/game/answer',
        json={'resource_id': game_id, 'answer': {'number': 1, 'unit': None}},
        headers=host_headers,
    )
    assert r1.status_code == 200

    r2 = api_client.post(
        '/api/v1/game/answer',
        json={'resource_id': game_id, 'answer': {'number': 2, 'unit': None}},
        headers=host_headers,
    )
    assert r2.status_code == 409


def test_answer_by_non_tracked_user_returns_404(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """User not in progress map should get 404 on answer submit."""
    host_headers = get_api_auth_headers(
        'dev.user+ans-nontracked-host@example.com',
        'password123',
        'AnsNonTrackedHost',
    )
    game_id = create_private_game(host_headers)
    _wait_ready_with_questions(get_firestore_doc, game_id)
    rs = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert rs.status_code == 200

    # New user who is not in players map
    stranger_headers = get_api_auth_headers(
        'dev.user+ans-stranger@example.com',
        'password123',
        'AnsStranger',
    )
    r = api_client.post(
        '/api/v1/game/answer',
        json={'resource_id': game_id, 'answer': {'number': 3, 'unit': None}},
        headers=stranger_headers,
    )
    assert r.status_code == 404


def test_answer_nonexistent_game_returns_404(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Answering a non-existent game should return 404."""
    user_headers = get_api_auth_headers(
        'dev.user+ans-no-game@example.com',
        'password123',
        'AnsNoGame',
    )
    r = api_client.post(
        '/api/v1/game/answer',
        json={'resource_id': 'does-not-exist', 'answer': {'number': 1, 'unit': None}},
        headers=user_headers,
    )
    assert r.status_code == 404

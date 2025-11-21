"""End-to-end happy path: create → join → start → answer all → finish.

Covers the Phase 3 flow from the testing roadmap.
"""

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
    timeout_s: float = 10.0,
    interval_s: float = 0.1,
) -> dict[str, Any]:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc and doc.get('state') in desired_states:
            return doc
        time.sleep(interval_s)
    raise AssertionError('Desired game state not reached in time')


def _wait_all_answered(
    get_firestore_doc: Callable[[str], dict[str, Any]],
    game_id: str,
    *,
    timeout_s: float = 20.0,
    interval_s: float = 0.1,
) -> dict[str, Any]:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        progress = (doc.get('progress') or {}) if doc else {}
        if progress and progress.get('all_answered') is True:
            return doc
        time.sleep(interval_s)
    raise AssertionError('Progress did not reach all_answered=True in time')


def _wait_ready_with_questions(
    get_firestore_doc: Callable[[str], dict[str, Any]],
    game_id: str,
    *,
    timeout_s: float = 30.0,
    interval_s: float = 0.1,
) -> list[str]:
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc and doc.get('state') == 2 and doc.get('question_uids'):
            return [str(u) for u in doc['question_uids']]
        time.sleep(interval_s)
    raise AssertionError('Game not ready with questions in time')


def test_e2e_happy_path_two_players_full_rounds(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Run the canonical flow across APIs and Firestore state transitions."""
    # A) Create two users; user A creates private game; user B joins by id
    host_headers = get_api_auth_headers(
        'dev.user+e2e-host@example.com',
        'password123',
        'E2EHost',
    )
    joiner_headers = get_api_auth_headers(
        'dev.user+e2e-joiner@example.com',
        'password123',
        'E2EJoiner',
    )

    game_id = create_private_game(host_headers)

    # Wait until LOBBY_READY and questions populated
    qids = _wait_ready_with_questions(get_firestore_doc, game_id)
    assert len(qids) >= 1

    # Joiner joins by id → back to NOT_READY then READY again
    rj = api_client.post(
        '/api/v1/game/join',
        json={'resource_id': game_id},
        headers=joiner_headers,
    )
    assert rj.status_code == 200
    _ = _wait_ready_with_questions(get_firestore_doc, game_id)

    # B) Host starts game; verify first question revealed and progress initialized
    rs = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert rs.status_code == 200
    d_started = _wait_until_state(get_firestore_doc, game_id, {3, 5})
    assert d_started.get('question_uid') in set(qids)
    assert d_started.get('question_order') == 1
    progress = (d_started.get('progress') or {}).get('answered') or {}
    assert isinstance(progress, dict)
    assert all(v is False for v in progress.values())

    # C) Both players submit answers; verify each round finishes and results revealed
    # Loop through all questions; for all but last, advance via next_question
    total_questions = len(qids)
    for idx in range(total_questions):
        # Submit answers
        rh = api_client.post(
            '/api/v1/game/answer',
            json={'resource_id': game_id, 'answer': {'number': 1234, 'unit': None}},
            headers=host_headers,
        )
        assert rh.status_code == 200
        rj2 = api_client.post(
            '/api/v1/game/answer',
            json={'resource_id': game_id, 'answer': {'number': 1234, 'unit': None}},
            headers=joiner_headers,
        )
        assert rj2.status_code == 200

        # After last active player answers, progress should reflect all_answered
        d_finished = _wait_all_answered(get_firestore_doc, game_id)
        assert d_finished['progress']['all_answered'] is True

        is_last = idx == total_questions - 1
        if not is_last:
            # D) Host advances until last; verify next question state
            rn = api_client.post(
                '/api/v1/game/next_question',
                json={'resource_id': game_id},
                headers=host_headers,
            )
            assert rn.status_code == 200
            d_next = _wait_until_state(
                get_firestore_doc,
                game_id,
                {3, 5},
            )
            assert d_next.get('question_order') == idx + 2
            assert d_next.get('question_uid') in set(qids)
        else:
            # E) Last question answered should trigger end; state becomes
            # GAME_FINISHED (8)
            _ = _wait_until_state(get_firestore_doc, game_id, {8})

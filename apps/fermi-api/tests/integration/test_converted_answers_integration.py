"""Integration tests for converted_answers in players_results."""

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


def test_converted_answers_populated_for_both_players(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
    get_players_results_doc: Callable[[str, str], dict[str, Any]],
) -> None:
    """Verify that converted_answers is populated correctly for all players.

    This test verifies the fix for a race condition where the last answering
    player's result was not included in the converted_answers computation due
    to Firestore transaction read-before-write semantics.
    """
    # Create host
    host_headers = get_api_auth_headers(
        'dev.user+conv-host@example.com',
        'password123',
        'ConvHost',
    )
    game_id = create_private_game(host_headers)
    qids, _ = _wait_ready_with_questions(get_firestore_doc, game_id)

    # Joiner joins
    joiner_headers = get_api_auth_headers(
        'dev.user+conv-joiner@example.com',
        'password123',
        'ConvJoiner',
    )
    rj = api_client.post(
        '/api/v1/game/join',
        json={'resource_id': game_id},
        headers=joiner_headers,
    )
    assert rj.status_code == 200

    # Wait for ready again
    qids, _ = _wait_ready_with_questions(get_firestore_doc, game_id)

    # Start game
    rs = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert rs.status_code == 200
    doc = _wait_until_state(get_firestore_doc, game_id, {3, 5})
    curr_q = doc['question_uid']

    # Both players submit answers (using dimensionless for simplicity)
    rh = api_client.post(
        '/api/v1/game/answer',
        json={'resource_id': game_id, 'answer': {'number': 1000, 'unit': None}},
        headers=host_headers,
    )
    assert rh.status_code == 200

    rj2 = api_client.post(
        '/api/v1/game/answer',
        json={'resource_id': game_id, 'answer': {'number': 2000, 'unit': None}},
        headers=joiner_headers,
    )
    assert rj2.status_code == 200

    # Wait for finished state
    _wait_until_state(get_firestore_doc, game_id, {4, 6})

    # Fetch the players_results document
    pr_doc = get_players_results_doc(game_id, curr_q)
    assert pr_doc, 'players_results document should exist'
    assert pr_doc.get('revealed') is True, 'results should be revealed'

    players_results = pr_doc.get('players_results', {})
    assert len(players_results) == 2, 'should have 2 player results'

    # Both players should have converted_answers populated
    for player_id, player_result in players_results.items():
        converted = player_result.get('converted_answers')
        assert converted is not None, f'{player_id} should have converted_answers'
        assert len(converted) == 1, f'{player_id} should see 1 other player'
        # The converted answer should have the other player's ID as key
        other_ids = [pid for pid in players_results.keys() if pid != player_id]
        assert other_ids[0] in converted, f'{player_id} should see {other_ids[0]}'

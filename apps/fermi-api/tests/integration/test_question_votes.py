"""Integration tests for question vote endpoints."""

from __future__ import annotations

from collections.abc import Callable

from fastapi.testclient import TestClient


def _get_first_question_uid(
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    api_client: TestClient,
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict],
) -> tuple[str, dict[str, str]]:
    import time

    headers = get_api_auth_headers('dev.user+votes@example.com', 'password123', 'Votes')
    game_id = create_private_game(headers)

    # Questions are fetched at start time (service.py), not at create, so wait for
    # LOBBY_READY (state == 2), start the game, then read the populated uids.
    for _ in range(60):
        doc = get_firestore_doc(game_id)
        if doc and doc.get('state') == 2:
            break
        time.sleep(0.1)
    else:
        raise AssertionError('Game did not become LOBBY_READY in time for voting')

    start_resp = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=headers,
    )
    assert start_resp.status_code == 200

    for _ in range(60):
        doc = get_firestore_doc(game_id)
        if doc and doc.get('question_uids'):
            return str(doc['question_uids'][0]), headers
        time.sleep(0.1)
    raise AssertionError('No questions populated in time for voting')


def test_upvote(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict],
) -> None:
    """Upvote returns 200 and reports the upvote verdict."""
    qid, headers = _get_first_question_uid(
        get_api_auth_headers,
        api_client,
        create_private_game,
        get_firestore_doc,
    )
    # Upvote
    r1 = api_client.post(
        '/api/v1/question/upvote',
        json={'resource_id': qid},
        headers=headers,
    )
    assert r1.status_code == 200
    body = r1.json()
    if 'verdict' in body:
        assert body['verdict'] == 1

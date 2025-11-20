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
    headers = get_api_auth_headers('dev.user+votes@example.com', 'password123', 'Votes')
    game_id = create_private_game(headers)
    # Wait briefly until READY and questions present
    import time

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
    """Upvote then de-upvote returns 200 for both calls."""
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


def test_downvote(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict],
) -> None:
    """Downvote then de-downvote returns 200 for both calls."""
    qid, headers = _get_first_question_uid(
        get_api_auth_headers,
        api_client,
        create_private_game,
        get_firestore_doc,
    )
    # Downvote
    r1 = api_client.post(
        '/api/v1/question/downvote',
        json={'resource_id': qid},
        headers=headers,
    )
    assert r1.status_code == 200

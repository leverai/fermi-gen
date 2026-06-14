"""Integration tests for POST /game/create (private)."""

from collections.abc import Callable

from fastapi.testclient import TestClient


def test_create_private_game_creates_firestore_game_doc(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict],
) -> None:
    """POST /game/create creates Firestore doc with expected initial fields.

    Asserts:
    - Document exists with matching id
    - state is LOBBY_READY (questions are fetched at start, not create)
    - players map contains host and marks them as host/active
    - join_url present
    """
    headers = get_api_auth_headers(
        'dev.user+create@example.com',
        'password123',
        'Dev Create',
    )

    # Basic create; helper uses defaults for settings
    game_id = create_private_game(headers)

    doc = get_firestore_doc(game_id)
    assert doc, 'expected Firestore game doc to exist'
    assert doc['id'] == game_id
    # Lobby is ready immediately; there is no background fetch to wait on.
    assert doc['state'] == 2
    assert isinstance(doc['join_url'], str)
    assert doc['join_url']

    players = doc['players']
    host_id = doc['host']
    assert host_id in players
    host_info = players[host_id]
    assert host_info['is_host'] is True
    assert host_info['is_active'] is True


def test_create_private_game_does_not_fetch_questions(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict],
    list_firestore_subcollection_docs: Callable[[str, str], list[str]],
) -> None:
    """Questions are fetched at start time, so create must not populate them.

    Asserts:
    - state is LOBBY_READY (2) right after create
    - question_uids is empty/absent
    - questions/*, answers/*, players_results/* subcollections are empty
    """
    headers = get_api_auth_headers(
        'dev.user+create-no-fetch@example.com',
        'password123',
        'Dev Create No Fetch',
    )

    game_id = create_private_game(headers)

    doc = get_firestore_doc(game_id)
    assert doc, 'expected Firestore game doc to exist'
    assert doc['state'] == 2, 'lobby should be ready immediately'
    assert not doc.get('question_uids'), 'questions must not be fetched at create'

    # No question/answer/results documents should exist before start.
    assert not list_firestore_subcollection_docs(game_id, 'questions')
    assert not list_firestore_subcollection_docs(game_id, 'answers')
    assert not list_firestore_subcollection_docs(game_id, 'players_results')

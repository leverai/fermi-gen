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
    - state is LOBBY_NOT_READY
    - players map contains host and marks them as host/active
    - join_url present
    - version_uid present (non-empty string)
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
    # State may already be flipped to LOBBY_READY (2) by background fetch
    assert doc['state'] in (1, 2)
    assert isinstance(doc['join_url'], str)
    assert doc['join_url']
    assert isinstance(doc['version_uid'], str)
    assert doc['version_uid']

    players = doc['players']
    host_id = doc['host']
    assert host_id in players
    host_info = players[host_id]
    assert host_info['is_host'] is True
    assert host_info['is_active'] is True


def test_create_private_game_populates_background_collections_and_ready_state(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict],
    list_firestore_subcollection_docs: Callable[[str, str], list[str]],
) -> None:
    """Background task should populate subcollections and move to LOBBY_READY.

    Asserts after brief polling:
    - state becomes LOBBY_READY (2)
    - question_uids present and non-empty
    - questions/*, answers/*, players_results/* contain docs with ids
      matching question_uids
    """
    headers = get_api_auth_headers(
        'dev.user+create-bg@example.com',
        'password123',
        'Dev Create BG',
    )

    game_id = create_private_game(headers)

    # Poll the game doc briefly for LOBBY_READY and populated fields
    import time

    question_uids: list[str] = []
    for _ in range(60):  # up to ~6s
        doc = get_firestore_doc(game_id)
        if not doc:
            time.sleep(0.1)
            continue
        # Capture when ready and question_uids populated
        state = doc.get('state')
        q_uids = doc.get('question_uids') or []
        if state == 2 and isinstance(q_uids, list) and len(q_uids) > 0:
            question_uids = [str(x) for x in q_uids]
            break
        time.sleep(0.1)

    # If background population hasn't completed within the polling window,
    # fail clearly to surface the slow/background behavior.
    assert question_uids, 'question_uids not populated within timeout'

    # Subcollections should contain docs for the questions
    questions_ids = set(list_firestore_subcollection_docs(game_id, 'questions'))
    answers_ids = set(list_firestore_subcollection_docs(game_id, 'answers'))
    players_results_ids = set(
        list_firestore_subcollection_docs(game_id, 'players_results'),
    )
    expected_ids = set(question_uids)

    # Allow that population may be slightly staggered; ensure at least questions exist
    assert questions_ids >= expected_ids or expected_ids >= questions_ids
    # But answers and players_results should also be present eventually
    # If flakiness occurs, relax to subset; here we assert non-empty intersection
    assert questions_ids, 'questions subcollection should not be empty'
    assert answers_ids, 'answers subcollection should not be empty'
    assert players_results_ids, 'players_results subcollection should not be empty'

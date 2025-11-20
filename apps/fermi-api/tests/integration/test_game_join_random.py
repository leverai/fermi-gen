"""Integration tests for POST /game/join_random (public games)."""

from __future__ import annotations

import time
from collections.abc import Callable

from fastapi.testclient import TestClient


def _wait_until(
    fn: Callable[[], dict],
    *,
    timeout_s: float = 6.0,
    interval_s: float = 0.1,
) -> list[dict]:
    """Poll a callable returning a dict and collect snapshots until timeout.

    Returns the list of collected snapshots (may be empty if fn raises repeatedly).
    """
    snapshots: list[dict] = []
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            snap = fn()
            if isinstance(snap, dict) and snap:
                snapshots.append(snap)
        except Exception:
            raise
        time.sleep(interval_s)
    return snapshots


def _join_random(
    client: TestClient,
    headers: dict[str, str],
    *,
    n_questions: int = 3,
    category: str | None = None,
    difficulty: str | None = None,
) -> str:
    payload = {
        # The current request model inherits from IdModel; resource_id is ignored.
        'resource_id': 'ignored',
        'question_round_settings': {
            'n_questions': n_questions,
            'category': category,
            'difficulty': difficulty,
        },
    }
    r = client.post(
        '/api/v1/game/join_random',
        json=payload,
        headers=headers,
    )
    r.raise_for_status()
    return r.json()['resource_id']


def test_join_random_creates_public_game_when_no_match(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    get_firestore_doc: Callable[[str], dict],
    list_firestore_subcollection_docs: Callable[[str, str], list[str]],
) -> None:
    """When no matching public game exists, it should create one and return its id."""
    user_headers = get_api_auth_headers(
        'dev.user+randcreate@example.com',
        'password123',
        'RandCreate',
    )

    game_id = _join_random(
        api_client,
        user_headers,
        n_questions=3,
        category=None,
        difficulty=None,
    )

    # Game doc should exist and be public
    doc = get_firestore_doc(game_id)
    assert doc, 'expected Firestore game doc to exist'
    assert doc['id'] == game_id
    assert doc['private'] is False
    assert doc.get('category') is None
    # State may be NOT_READY initially, then READY after background population
    assert doc['state'] in (1, 2)

    # Poll until ready and populated
    question_uids: list[str] = []
    for _ in range(60):
        d = get_firestore_doc(game_id)
        if d and d.get('state') == 2 and d.get('question_uids'):
            question_uids = [str(u) for u in d['question_uids']]
            break
        time.sleep(0.1)
    assert question_uids, 'question_uids not populated within timeout'

    # Subcollections should be non-empty
    questions_ids = set(
        list_firestore_subcollection_docs(game_id, 'questions'),
    )
    answers_ids = set(
        list_firestore_subcollection_docs(game_id, 'answers'),
    )
    players_results_ids = set(
        list_firestore_subcollection_docs(game_id, 'players_results'),
    )
    assert questions_ids, 'questions subcollection should not be empty'
    assert answers_ids, 'answers subcollection should not be empty'
    assert players_results_ids, 'players_results subcollection should not be empty'


def test_join_random_joins_existing_public_game_and_repopulates(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    get_firestore_doc: Callable[[str], dict],
    list_firestore_subcollection_docs: Callable[[str, str], list[str]],
    create_emulator_user_and_get_token: Callable[[str, str, str], dict],
    mark_questions_seen_for_user: Callable[[str, list[str]], None],
) -> None:
    """Second user calling join_random join existing game and trigger re-fetch."""
    # First user creates/joins a public game via join_random
    user1_headers = get_api_auth_headers(
        'dev.user+randhost@example.com',
        'password123',
        'RandHost',
    )
    game_id = _join_random(
        api_client,
        user1_headers,
        n_questions=3,
        category=None,
        difficulty=None,
    )

    # Wait until initial population completes
    initial_q_uids: list[str] = []
    initial_version = ''
    for _ in range(60):
        doc = get_firestore_doc(game_id)
        if doc and doc.get('state') == 2 and doc.get('question_uids'):
            initial_q_uids = [str(u) for u in doc['question_uids']]
            initial_version = str(doc.get('version_uid', ''))
            break
        time.sleep(0.1)
    assert initial_q_uids, 'expected initial questions populated'
    assert initial_version

    before_players_n = len(get_firestore_doc(game_id)['players'])
    host_id = get_firestore_doc(game_id)['host']

    # Prepare second user; mark one initial question as seen to encourage re-fetch
    creds = create_emulator_user_and_get_token(
        'dev.user+randjoin@example.com',
        'password123',
        'RandJoin',
    )
    joiner_uid = creds['localId']
    if initial_q_uids:
        mark_questions_seen_for_user(joiner_uid, [initial_q_uids[0]])

    # Exchange emulator token for API access token
    token_resp = api_client.post(
        '/api/v1/auth/token',
        headers={
            'Authorization': f'Bearer {creds["idToken"]}',
        },
    )
    token_resp.raise_for_status()
    user2_headers = {'Authorization': f'Bearer {token_resp.json()["access_token"]}'}

    # Second user calls join_random with same settings; should join existing game
    joined_game_id = _join_random(
        api_client,
        user2_headers,
        n_questions=3,
        category=None,
        difficulty=None,
    )
    assert joined_game_id == game_id

    # Observe state snapshots to ensure it returns to READY
    snaps = _wait_until(lambda: get_firestore_doc(game_id), timeout_s=6.0)
    assert snaps, 'no snapshots collected from Firestore emulator'
    states = [s.get('state') for s in snaps if 'state' in s]
    assert 2 in states, 'did not observe return to LOBBY_READY after join_random'

    # Version should change
    final_version = next(
        (str(s.get('version_uid')) for s in reversed(snaps) if s.get('version_uid')),
        '',
    )
    assert final_version
    assert final_version != initial_version

    # Questions should be re-fetched (ideally different when supply allows)
    final_doc = get_firestore_doc(game_id)
    final_q_uids = [str(u) for u in final_doc.get('question_uids', [])]
    assert final_q_uids, 'expected question_uids to be present after re-fetch'
    assert final_q_uids != initial_q_uids, (
        'question_uids did not change after join_random'
    )

    # Subcollections should be non-empty again
    questions_ids = set(
        list_firestore_subcollection_docs(game_id, 'questions'),
    )
    answers_ids = set(
        list_firestore_subcollection_docs(game_id, 'answers'),
    )
    players_results_ids = set(
        list_firestore_subcollection_docs(game_id, 'players_results'),
    )
    assert questions_ids, 'questions subcollection should not be empty after re-fetch'
    assert answers_ids, 'answers subcollection should not be empty after re-fetch'
    assert players_results_ids, (
        'players_results subcollection should not be empty after re-fetch'
    )

    # Players should increase by 1 and host unchanged; still public
    assert len(final_doc['players']) == before_players_n + 1
    assert final_doc['host'] == host_id
    assert final_doc['private'] is False

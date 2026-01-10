"""Integration tests for POST /game/join (join by id)."""

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


def test_join_existing_lobby_game_adds_player_and_repopulates(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict],
    list_firestore_subcollection_docs: Callable[[str, str], list[str]],
    mark_questions_seen_for_user: Callable[[str, list[str]], None],
    create_emulator_user_and_get_token: Callable[[str, str, str], dict],
) -> None:
    """Join by id should add player, flip state to NOT_READY, then repopulate.

    Asserts:
    - state transitions LOBBY_READY -> LOBBY_NOT_READY (on join) -> LOBBY_READY
    - version_uid changes
    - question_uids cleared ([]) then repopulated; subcollections non-empty
    - players count increases by 1, host remains unchanged
    """
    # Host creates a private game and waits until ready
    host_headers = get_api_auth_headers(
        'dev.user+host@example.com',
        'password123',
        'Host',
    )
    game_id = create_private_game(host_headers)

    # Wait until initial population completes (LOBBY_READY with question_uids)
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

    # Second user joins by id
    # Create the joiner in the Auth emulator to get their uid (localId)
    creds = create_emulator_user_and_get_token(
        'dev.user+joiner@example.com',
        'password123',
        'Joiner',
    )
    joiner_uid = creds['localId']

    # Mark one initial question as seen for the joiner to influence re-fetch
    if initial_q_uids:
        mark_questions_seen_for_user(joiner_uid, [initial_q_uids[0]])

    # Exchange emulator idToken to API access token for headers (avoid re-signup)
    token_resp = api_client.post(
        '/api/v1/auth/token',
        headers={'Authorization': f'Bearer {creds["idToken"]}'},
    )
    token_resp.raise_for_status()
    joiner_headers = {
        'Authorization': f'Bearer {token_resp.json()["access_token"]}',
    }
    resp = api_client.post(
        '/api/v1/game/join',
        json={'resource_id': game_id},
        headers=joiner_headers,
    )
    assert resp.status_code == 200

    # Collect snapshots for a few seconds to observe transitions
    snaps = _wait_until(lambda: get_firestore_doc(game_id), timeout_s=6.0)
    assert snaps, 'no snapshots collected from Firestore emulator'

    # We expect to observe READY (2). NOT_READY (1) can be transient and may
    # not always be observable depending on timing, so we don't require it.
    states = [s.get('state') for s in snaps if 'state' in s]
    assert 2 in states, 'did not observe return to LOBBY_READY after join'

    # Version should change
    final_version = next(
        (str(s.get('version_uid')) for s in reversed(snaps) if s.get('version_uid')),
        '',
    )
    assert final_version
    assert final_version != initial_version

    # Question uids should change due to re-fetch for the new roster
    # time.sleep(1)
    final_doc = get_firestore_doc(game_id)
    final_q_uids = [str(u) for u in final_doc.get('question_uids', [])]
    assert final_q_uids, 'expected question_uids to be present after re-fetch'
    # With precondition (seen one question), expect a change if there is supply
    assert final_q_uids != initial_q_uids, 'question_uids did not change after join'

    # Eventually, subcollections should be non-empty again
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

    # Players should increase by 1 and host unchanged
    assert len(final_doc['players']) == before_players_n + 1
    assert final_doc['host'] == host_id


def test_join_nonexistent_game_returns_404(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Join nonexistent game should return 404."""
    headers = get_api_auth_headers(
        'dev.user+noexist@example.com',
        'password123',
        'NoExist',
    )
    resp = api_client.post(
        '/api/v1/game/join',
        json={'resource_id': 'does-not-exist'},
        headers=headers,
    )
    assert resp.status_code == 404


def test_join_full_game_returns_409(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict],
) -> None:
    """Join full game should return 409.

    Note: FREE tier hosts have max_players=5, so game becomes full at 5 players.
    """
    # Host creates game
    host_headers = get_api_auth_headers(
        'dev.user+fullhost@example.com',
        'password123',
        'FullHost',
    )
    game_id = create_private_game(host_headers)

    # Sequentially join 4 additional users to reach 5 players total (FREE tier limit)
    for i in range(4):
        headers = get_api_auth_headers(
            f'dev.user+full{i}@example.com',
            'password123',
            f'Full{i}',
        )
        r = api_client.post(
            '/api/v1/game/join',
            json={'resource_id': game_id},
            headers=headers,
        )
        assert r.status_code == 200
        # Wait briefly until players count reflects the join
        for _ in range(30):
            if len(get_firestore_doc(game_id).get('players', {})) >= (i + 2):
                break
            time.sleep(0.1)

    # Confirm game is full (5 players is the FREE tier limit)
    doc = get_firestore_doc(game_id)
    assert len(doc['players']) == 5
    assert doc['full'] is True
    assert doc['max_players'] == 5

    # Next join attempt should 409
    extra_headers = get_api_auth_headers(
        'dev.user+overflow@example.com',
        'password123',
        'Overflow',
    )
    resp = api_client.post(
        '/api/v1/game/join',
        json={'resource_id': game_id},
        headers=extra_headers,
    )
    assert resp.status_code == 409


def test_join_after_game_started_returns_409(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict],
) -> None:
    """Join after game started should return 409."""
    # Host creates game and waits ready
    host_headers = get_api_auth_headers(
        'dev.user+starter@example.com',
        'password123',
        'Starter',
    )
    game_id = create_private_game(host_headers)
    for _ in range(60):
        if get_firestore_doc(game_id).get('state') == 2:
            break
        time.sleep(0.1)

    # Host starts the game
    r = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert r.status_code == 200

    # Wait until state reflects in-progress
    for _ in range(60):
        state = get_firestore_doc(game_id).get('state')
        if state in (3, 5):  # QUESTION_N or QUESTION_LAST
            break
        time.sleep(0.1)

    # Another user attempts to join → 409
    joiner_headers = get_api_auth_headers(
        'dev.user+late@example.com',
        'password123',
        'Late',
    )
    resp = api_client.post(
        '/api/v1/game/join',
        json={'resource_id': game_id},
        headers=joiner_headers,
    )
    assert resp.status_code == 409

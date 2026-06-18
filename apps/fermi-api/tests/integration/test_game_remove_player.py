"""Integration tests for POST /game/remove_player."""

from __future__ import annotations

import time
from collections.abc import Callable
from typing import Any

from fastapi.testclient import TestClient


def _wait_ready(
    get_firestore_doc: Callable[[str], dict[str, Any]],
    game_id: str,
) -> dict[str, Any]:
    deadline = time.time() + 6.0
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc and doc.get('state') == 2 and doc.get('players'):
            return doc
        time.sleep(0.1)
    raise AssertionError('Game did not become LOBBY_READY in time')


def _start_game(
    api_client: TestClient,
    get_firestore_doc: Callable[[str], dict[str, Any]],
    game_id: str,
    headers: dict[str, str],
) -> dict[str, Any]:
    r = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=headers,
    )
    assert r.status_code == 200
    deadline = time.time() + 6.0
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc and doc.get('state') in (3, 5):
            return doc
        time.sleep(0.1)
    raise AssertionError('Game did not transition to a question state')


def test_remove_non_host_other_returns_403(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
    create_emulator_user_and_get_token: Callable[[str, str, str], dict[str, Any]],
) -> None:
    """Non-host attempting to remove another player should return 403."""
    host_headers = get_api_auth_headers(
        'dev.user+rm-403-host@example.com',
        'password123',
        'Rm403Host',
    )
    game_id = create_private_game(host_headers)
    _ = _wait_ready(get_firestore_doc, game_id)
    creds = create_emulator_user_and_get_token(
        'dev.user+rm-403-joiner@example.com',
        'password123',
        'Rm403Joiner',
    )
    token_resp = api_client.post(
        '/api/v1/auth/token',
        headers={'Authorization': f'Bearer {creds["idToken"]}'},
    )
    joiner_headers = {'Authorization': f'Bearer {token_resp.json()["access_token"]}'}
    api_client.post(
        '/api/v1/game/join',
        json={'resource_id': game_id},
        headers=joiner_headers,
    )
    _ = _wait_ready(get_firestore_doc, game_id)

    # Joiner attempts to remove host
    host_id = get_firestore_doc(game_id)['host']
    r = api_client.post(
        '/api/v1/game/remove_player',
        json={'resource_id': game_id, 'player_id': host_id},
        headers=joiner_headers,
    )
    assert r.status_code == 403


def test_remove_in_question_makes_finished_when_last_pending_removed(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
    create_emulator_user_and_get_token: Callable[[str, str, str], dict[str, Any]],
) -> None:
    """Removing the last pending-answer player finishes and reveals the round."""
    host_headers = get_api_auth_headers(
        'dev.user+rm-finish-host@example.com',
        'password123',
        'RmFinishHost',
    )
    game_id = create_private_game(host_headers)
    _ = _wait_ready(get_firestore_doc, game_id)
    creds = create_emulator_user_and_get_token(
        'dev.user+rm-finish-joiner@example.com',
        'password123',
        'RmFinishJoiner',
    )
    joiner_uid = creds['localId']
    token_resp = api_client.post(
        '/api/v1/auth/token',
        headers={'Authorization': f'Bearer {creds["idToken"]}'},
    )
    joiner_headers = {'Authorization': f'Bearer {token_resp.json()["access_token"]}'}
    api_client.post(
        '/api/v1/game/join',
        json={'resource_id': game_id},
        headers=joiner_headers,
    )
    _ = _wait_ready(get_firestore_doc, game_id)

    _start_game(api_client, get_firestore_doc, game_id, host_headers)

    # Host answers; joiner pending
    rans = api_client.post(
        '/api/v1/game/answer',
        json={'resource_id': game_id, 'answer': {'number': 42, 'unit': None}},
        headers=host_headers,
    )
    assert rans.status_code == 200

    # Host removes pending joiner → should finish round and reveal
    rr = api_client.post(
        '/api/v1/game/remove_player',
        json={'resource_id': game_id, 'player_id': joiner_uid},
        headers=host_headers,
    )
    assert rr.status_code == 200
    deadline = time.time() + 6.0
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if (
            doc.get('state') in (4, 6)
            and doc.get('progress', {}).get('all_answered') is True
        ):
            break
        time.sleep(0.1)
    else:
        raise AssertionError('Game did not transition to *_FINISHED after removal')


def test_remove_last_active_player_ends_game(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
    create_emulator_user_and_get_token: Callable[[str, str, str], dict[str, Any]],
) -> None:
    """Removing last active player should end game."""
    host_headers = get_api_auth_headers(
        'dev.user+rm-last-host@example.com',
        'password123',
        'RmLastHost',
    )
    game_id = create_private_game(host_headers)
    _ = _wait_ready(get_firestore_doc, game_id)
    creds = create_emulator_user_and_get_token(
        'dev.user+rm-last-joiner@example.com',
        'password123',
        'RmLastJoiner',
    )
    joiner_uid = creds['localId']
    token_resp = api_client.post(
        '/api/v1/auth/token',
        headers={'Authorization': f'Bearer {creds["idToken"]}'},
    )
    joiner_headers = {'Authorization': f'Bearer {token_resp.json()["access_token"]}'}
    api_client.post(
        '/api/v1/game/join',
        json={'resource_id': game_id},
        headers=joiner_headers,
    )
    _ = _wait_ready(get_firestore_doc, game_id)

    _start_game(api_client, get_firestore_doc, game_id, host_headers)

    # Remove joiner first
    api_client.post(
        '/api/v1/game/remove_player',
        json={'resource_id': game_id, 'player_id': joiner_uid},
        headers=host_headers,
    )
    # Host removes self → ends game
    host_id = get_firestore_doc(game_id)['host']
    r = api_client.post(
        '/api/v1/game/remove_player',
        json={'resource_id': game_id, 'player_id': host_id},
        headers=host_headers,
    )
    assert r.status_code == 200

    # Wait for end
    deadline = time.time() + 6.0
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc.get('state') in (8, 9):  # GAME_FINISHED or GAME_ABORTED
            break
        time.sleep(0.1)
    else:
        raise AssertionError('Game did not end after removing last active player')


def test_player_self_remove_in_lobby_allowed(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
    create_emulator_user_and_get_token: Callable[[str, str, str], dict[str, Any]],
) -> None:
    """Player removing self in lobby should succeed and delete their entry."""
    host_headers = get_api_auth_headers(
        'dev.user+rm-self-lobby-host@example.com',
        'password123',
        'RmSelfLobbyHost',
    )
    game_id = create_private_game(host_headers)
    _ = _wait_ready(get_firestore_doc, game_id)

    creds = create_emulator_user_and_get_token(
        'dev.user+rm-self-lobby-joiner@example.com',
        'password123',
        'RmSelfLobbyJoiner',
    )
    joiner_uid = creds['localId']
    token_resp = api_client.post(
        '/api/v1/auth/token',
        headers={'Authorization': f'Bearer {creds["idToken"]}'},
    )
    token_resp.raise_for_status()
    joiner_headers = {'Authorization': f'Bearer {token_resp.json()["access_token"]}'}

    rj = api_client.post(
        '/api/v1/game/join',
        json={'resource_id': game_id},
        headers=joiner_headers,
    )
    assert rj.status_code == 200
    _ = _wait_ready(get_firestore_doc, game_id)

    # Self-remove by joiner
    rr = api_client.post(
        '/api/v1/game/remove_player',
        json={'resource_id': game_id, 'player_id': joiner_uid},
        headers=joiner_headers,
    )
    assert rr.status_code == 200
    doc = get_firestore_doc(game_id)
    assert joiner_uid not in doc['players']

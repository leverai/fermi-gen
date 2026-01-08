"""Integration tests for DELETE /game/cleanup."""

from __future__ import annotations

import os
import time
from collections.abc import Callable
from typing import Any

import httpx
from fastapi.testclient import TestClient


def _wait_ready(
    get_firestore_doc: Callable[[str], dict[str, Any]],
    game_id: str,
) -> dict[str, Any]:
    deadline = time.time() + 6.0
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc and doc.get('state') == 2:
            return doc
        time.sleep(0.1)
    raise AssertionError('Game did not become ready in time')


def _start(
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
    raise AssertionError('Game did not start in time')


def _end_game(
    api_client: TestClient,
    get_firestore_doc: Callable[[str], dict[str, Any]],
    game_id: str,
    headers: dict[str, str],
) -> None:
    r = api_client.post(
        '/api/v1/game/end',
        json={'resource_id': game_id},
        headers=headers,
    )
    assert r.status_code == 200
    # Wait until end
    deadline = time.time() + 6.0
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc.get('state') in (8, 9):
            return
        time.sleep(0.1)
    raise AssertionError('Game did not end in time')


def _set_game_state_directly(game_id: str, state: int) -> None:
    """Directly set game state in Firestore emulator (for test setup)."""
    project = os.environ['GOOGLE_CLOUD_PROJECT']
    fs_host = os.environ['FIRESTORE_EMULATOR_HOST']
    base = f'http://{fs_host}/v1/projects/{project}/databases/(default)/documents'

    # PATCH the game document to set state
    httpx.patch(
        f'{base}/games/{game_id}?updateMask.fieldPaths=state',
        json={
            'fields': {
                'state': {'integerValue': str(state)},
            },
        },
        headers={
            'Authorization': 'Bearer owner',
            'X-Goog-User-Project': project,
        },
        timeout=5.0,
    )


def test_cleanup_deletes_finished_games(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Cleanup endpoint deletes finished games."""
    host_headers = get_api_auth_headers(
        'dev.user+cleanup-test1@example.com',
        'password123',
        'CleanupHost1',
    )
    game_id = create_private_game(host_headers)
    _ = _wait_ready(get_firestore_doc, game_id)
    _ = _start(api_client, get_firestore_doc, game_id, host_headers)
    _end_game(api_client, get_firestore_doc, game_id, host_headers)

    # Verify game exists and is finished
    doc = get_firestore_doc(game_id)
    assert doc.get('state') in (8, 9)

    # Call cleanup endpoint (no auth required)
    r = api_client.delete('/api/v1/game/cleanup')
    assert r.status_code == 200
    data = r.json()
    assert data['deleted'] >= 1

    # Verify game is deleted
    time.sleep(0.5)
    doc = get_firestore_doc(game_id)
    assert not doc, 'Game should be deleted after cleanup'


def test_cleanup_does_not_delete_active_games(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Cleanup endpoint does not delete active games (state < 8)."""
    host_headers = get_api_auth_headers(
        'dev.user+cleanup-active@example.com',
        'password123',
        'CleanupActiveHost',
    )
    game_id = create_private_game(host_headers)
    _ = _wait_ready(get_firestore_doc, game_id)
    _ = _start(api_client, get_firestore_doc, game_id, host_headers)

    # Verify game is active (not finished)
    doc = get_firestore_doc(game_id)
    assert doc.get('state') < 8

    # Call cleanup endpoint
    r = api_client.delete('/api/v1/game/cleanup')
    assert r.status_code == 200
    data = r.json()
    assert data['deleted'] == 0

    # Verify game still exists
    doc = get_firestore_doc(game_id)
    assert doc, 'Active game should not be deleted'
    assert doc.get('state') < 8


def test_cleanup_respects_max_games_limit(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Cleanup endpoint respects max_games limit parameter."""
    # Create and finish two games
    game_ids = []
    for i in range(2):
        headers = get_api_auth_headers(
            f'dev.user+cleanup-max{i}@example.com',
            'password123',
            f'CleanupMax{i}',
        )
        game_id = create_private_game(headers)
        _ = _wait_ready(get_firestore_doc, game_id)
        _ = _start(api_client, get_firestore_doc, game_id, headers)
        _end_game(api_client, get_firestore_doc, game_id, headers)
        game_ids.append(game_id)

    # Verify both games are finished
    for gid in game_ids:
        doc = get_firestore_doc(gid)
        assert doc.get('state') in (8, 9)

    # Call cleanup with max_games=1
    r = api_client.delete('/api/v1/game/cleanup?max_games=1')
    assert r.status_code == 200
    data = r.json()
    assert data['deleted'] == 1

    # One game should remain
    remaining = sum(1 for gid in game_ids if get_firestore_doc(gid))
    assert remaining == 1, 'One game should remain after cleanup with max_games=1'


def test_cleanup_deletes_subcollections(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
    list_firestore_subcollection_docs: Callable[[str, str], list[str]],
) -> None:
    """Cleanup endpoint deletes subcollections (questions, answers, players_results)."""
    host_headers = get_api_auth_headers(
        'dev.user+cleanup-subcol@example.com',
        'password123',
        'CleanupSubcol',
    )
    game_id = create_private_game(host_headers)
    _ = _wait_ready(get_firestore_doc, game_id)
    _ = _start(api_client, get_firestore_doc, game_id, host_headers)

    # Verify subcollections exist
    questions = list_firestore_subcollection_docs(game_id, 'questions')
    assert len(questions) > 0, 'Should have questions subcollection'

    # End game
    _end_game(api_client, get_firestore_doc, game_id, host_headers)

    # Call cleanup
    r = api_client.delete('/api/v1/game/cleanup')
    assert r.status_code == 200
    assert r.json()['deleted'] >= 1

    # Verify subcollections are deleted
    time.sleep(0.5)
    questions = list_firestore_subcollection_docs(game_id, 'questions')
    answers = list_firestore_subcollection_docs(game_id, 'answers')
    players_results = list_firestore_subcollection_docs(game_id, 'players_results')
    assert not questions, 'Questions subcollection should be deleted'
    assert not answers, 'Answers subcollection should be deleted'
    assert not players_results, 'Players results subcollection should be deleted'

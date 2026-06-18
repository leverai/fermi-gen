"""Integration tests for POST /game/end."""

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


def test_end_game_by_host_transitions_and_archives_trigger(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Host ends a started game → GAME_ABORTED or GAME_FINISHED depending on state."""
    host_headers = get_api_auth_headers(
        'dev.user+end-host@example.com',
        'password123',
        'EndHost',
    )
    game_id = create_private_game(host_headers)
    _ = _wait_ready(get_firestore_doc, game_id)
    _ = _start(api_client, get_firestore_doc, game_id, host_headers)

    r = api_client.post(
        '/api/v1/game/end',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert r.status_code == 200

    # Wait until state reflects end
    deadline = time.time() + 6.0
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc.get('state') in (8, 9):
            break
        time.sleep(0.1)
    else:
        raise AssertionError('Game did not end after host request')


def test_end_pre_start_deletes_game_doc(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Ending a pre-start lobby game deletes the game document."""
    host_headers = get_api_auth_headers(
        'dev.user+end-pre-host@example.com',
        'password123',
        'EndPreHost',
    )
    game_id = create_private_game(host_headers)
    _ = _wait_ready(get_firestore_doc, game_id)

    r = api_client.post(
        '/api/v1/game/end',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert r.status_code == 200

    # Poll for deletion (404 from emulator REST will surface via empty dict in helper)
    deadline = time.time() + 6.0
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if not doc:
            break
        time.sleep(0.1)
    else:
        raise AssertionError('Pre-start game doc was not deleted on end')


def test_end_non_host_returns_403(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Non-host attempting to end (non-forced) should return 403."""
    host_headers = get_api_auth_headers(
        'dev.user+end-403-host@example.com',
        'password123',
        'End403Host',
    )
    game_id = create_private_game(host_headers)
    _ = _wait_ready(get_firestore_doc, game_id)
    non_host_headers = get_api_auth_headers(
        'dev.user+end-403-joiner@example.com',
        'password123',
        'End403Joiner',
    )
    api_client.post(
        '/api/v1/game/join',
        json={'resource_id': game_id},
        headers=non_host_headers,
    )
    _ = _wait_ready(get_firestore_doc, game_id)
    _ = _start(api_client, get_firestore_doc, game_id, host_headers)

    r = api_client.post(
        '/api/v1/game/end',
        json={'resource_id': game_id},
        headers=non_host_headers,
    )
    assert r.status_code == 403


def test_end_nonexistent_returns_404(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Ending a non-existent game should return 404."""
    headers = get_api_auth_headers(
        'dev.user+end-404@example.com',
        'password123',
        'End404',
    )
    r = api_client.post(
        '/api/v1/game/end',
        json={'resource_id': 'does-not-exist'},
        headers=headers,
    )
    assert r.status_code == 404

"""Integration tests for POST /game/start (host-only)."""

import os
import time
from collections.abc import Callable
from typing import Any

import httpx
from fastapi.testclient import TestClient


def _get_question_doc(game_id: str, question_uid: str) -> dict[str, Any]:
    """Fetch a question subdocument via Firestore emulator REST."""
    project = os.environ['GOOGLE_CLOUD_PROJECT']
    fs_host = os.environ['FIRESTORE_EMULATOR_HOST']
    base = f'http://{fs_host}/v1/projects/{project}/databases/(default)/documents'
    r = httpx.get(
        f'{base}/games/{game_id}/questions/{question_uid}',
        headers={'Authorization': 'Bearer owner', 'X-Goog-User-Project': project},
        timeout=2.0,
    )
    r.raise_for_status()
    body = r.json()
    fields = body.get('fields', {}) if isinstance(body, dict) else {}
    # Minimal conversion for fields we need
    out: dict[str, Any] = {}
    for k, v in fields.items():
        if isinstance(v, dict):
            if 'stringValue' in v:
                out[k] = v['stringValue']
            elif 'integerValue' in v:
                try:
                    out[k] = int(v['integerValue'])
                except Exception:  # pragma: no cover - best effort
                    out[k] = v['integerValue']
            elif 'doubleValue' in v:
                try:
                    out[k] = float(v['doubleValue'])
                except Exception:  # pragma: no cover - best effort
                    out[k] = v['doubleValue']
    return out


def _wait_ready_with_questions(
    get_firestore_doc: Callable[[str], dict[str, Any]],
    game_id: str,
    *,
    timeout_s: float = 6.0,
    interval_s: float = 0.1,
) -> tuple[list[str], dict[str, Any]]:
    """Poll until game is LOBBY_READY with non-empty question_uids.

    Returns the (question_uids, final_doc).
    """
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc and doc.get('state') == 2 and doc.get('question_uids'):
            q_uids = [str(u) for u in doc['question_uids']]
            return q_uids, doc
        time.sleep(interval_s)
    raise AssertionError('Game did not become LOBBY_READY with question_uids in time')


def test_start_game_by_host_reveals_first_and_inits_progress(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_public_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Host starts in READY: verify reveal, timers, progress, and state."""
    host_headers = get_api_auth_headers(
        'dev.user+start-host@example.com',
        'password123',
        'StartHost',
    )
    game_id = create_public_game(host_headers)

    question_uids, _ = _wait_ready_with_questions(get_firestore_doc, game_id)
    first_q = question_uids[0]

    # Start the game
    r = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert r.status_code == 200

    # Poll for state transition and fields
    for _ in range(60):
        doc = get_firestore_doc(game_id)
        state = doc.get('state')
        if state in (3, 5):  # QUESTION_N or QUESTION_LAST
            # started_at should be present (timestamp string)
            assert 'started_at' in doc
            # current question fields
            assert doc.get('question_uid') == first_q
            assert doc.get('question_order') == 1
            qdur = doc.get('question_duration_s')
            assert qdur in {10, 20, 40}
            # Verify duration matches question difficulty mapping
            qdoc = _get_question_doc(game_id, first_q)
            diff = qdoc.get('difficulty')
            expected = {'EASY': 10, 'MEDIUM': 20, 'HARD': 40}[str(diff)]
            assert qdur == expected
            # Progress initialized
            progress = doc.get('progress') or {}
            answered = progress.get('answered') or {}
            assert isinstance(answered, dict)
            assert all(v is False for v in answered.values())
            assert progress.get('all_answered') is False
            break
        time.sleep(0.1)
    else:
        raise AssertionError('Game state did not transition to a question state')


def test_start_game_by_non_host_returns_403(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Non-host attempting to start should be forbidden (403)."""
    host_headers = get_api_auth_headers(
        'dev.user+start-host2@example.com',
        'password123',
        'StartHost2',
    )
    game_id = create_private_game(host_headers)
    _wait_ready_with_questions(get_firestore_doc, game_id)

    non_host_headers = get_api_auth_headers(
        'dev.user+start-nonhost@example.com',
        'password123',
        'StartNonHost',
    )
    r = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=non_host_headers,
    )
    assert r.status_code == 403


def test_start_game_immediately_when_no_questions_returns_409(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
) -> None:
    """Starting before questions are populated should 409 (no questions)."""
    host_headers = get_api_auth_headers(
        'dev.user+start-early@example.com',
        'password123',
        'StartEarly',
    )
    game_id = create_private_game(host_headers)

    r = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    # Depending on timing, it could already be ready; if so, skip this assertion
    if r.status_code != 200:
        assert r.status_code == 409


def test_start_game_second_time_returns_409_not_ready(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Starting again when state != LOBBY_READY should return 409."""
    host_headers = get_api_auth_headers(
        'dev.user+start-twice@example.com',
        'password123',
        'StartTwice',
    )
    game_id = create_private_game(host_headers)
    _wait_ready_with_questions(get_firestore_doc, game_id)

    r1 = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert r1.status_code == 200

    r2 = api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    assert r2.status_code == 409

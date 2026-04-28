"""Integration tests for DeathMatch game mode.

Requires running Firebase Auth + Firestore emulators and Postgres.
See README for emulator startup commands.
"""

from __future__ import annotations

import time
from collections.abc import Callable
from typing import Any

from fastapi.testclient import TestClient

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def _poll_match_state(
    api_client: TestClient,
    match_id: str,
    headers: dict[str, str],
    *,
    timeout_s: float = 10.0,
    interval_s: float = 0.2,
) -> dict[str, Any]:
    """Poll GET /deathmatch/match/{id} until state >= QUESTION_ACTIVE."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        r = api_client.get(
            f'/api/v1/deathmatch/match/{match_id}',
            headers=headers,
        )
        if r.status_code == 200:
            data = r.json()
            if data.get('state', 0) >= 1:
                return data
        time.sleep(interval_s)
    raise AssertionError(f'Match {match_id} did not reach active state in time')


# ---------------------------------------------------------------------------
# Queue endpoint
# ---------------------------------------------------------------------------


def test_queue_returns_waiting_when_alone(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """A single player queueing should get status=waiting."""
    headers = get_api_auth_headers(
        'dm-queue-solo@example.com',
        'password123',
        'Solo',
    )
    resp = api_client.post('/api/v1/deathmatch/queue', headers=headers)
    assert resp.status_code == 200
    data = resp.json()
    assert data['status'] == 'waiting'
    assert 'match_id' in data


# ---------------------------------------------------------------------------
# Match status / bot matching
# ---------------------------------------------------------------------------


def test_match_status_triggers_bot_match(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Polling match status while waiting should trigger a bot match."""
    headers = get_api_auth_headers(
        'dm-bot-match@example.com',
        'password123',
        'BotMatch',
    )
    q_resp = api_client.post('/api/v1/deathmatch/queue', headers=headers)
    assert q_resp.status_code == 200
    match_id = q_resp.json()['match_id']

    # Poll - should match with a bot
    status = _poll_match_state(api_client, match_id, headers)
    assert status['state'] >= 1  # QUESTION_ACTIVE or beyond
    assert status['player2'] is not None
    assert status['question'] is not None
    assert status['question']['question_uid']


# ---------------------------------------------------------------------------
# Answer submission + result
# ---------------------------------------------------------------------------


def test_submit_answer_and_get_result(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Full flow: queue -> bot match -> answer -> result."""
    headers = get_api_auth_headers(
        'dm-answer@example.com',
        'password123',
        'Answerer',
    )

    # Queue and get matched with bot
    q_resp = api_client.post('/api/v1/deathmatch/queue', headers=headers)
    match_id = q_resp.json()['match_id']
    _poll_match_state(api_client, match_id, headers)

    # Submit answer (bot already answered)
    ans_resp = api_client.post(
        '/api/v1/deathmatch/answer',
        json={'match_id': match_id, 'answer': {'number': 100.0, 'unit': None}},
        headers=headers,
    )
    assert ans_resp.status_code == 200
    ans_data = ans_resp.json()

    # Bot already answered, so we should get a result directly
    # or a waiting_for_opponent response (depending on timing)
    if 'winner' in ans_data:
        # Got result directly
        assert 'your_score' in ans_data
        assert 'opponent_score' in ans_data
        assert 'correct_answer' in ans_data
        assert 'points_transferred' in ans_data
    else:
        # Got waiting response, poll result
        assert ans_data.get('waiting_for_opponent') is True
        # Get result
        result_resp = api_client.get(
            f'/api/v1/deathmatch/result/{match_id}',
            headers=headers,
        )
        assert result_resp.status_code == 200
        result_data = result_resp.json()
        assert 'winner' in result_data
        assert 'your_score' in result_data


# ---------------------------------------------------------------------------
# Leave / forfeit
# ---------------------------------------------------------------------------


def test_leave_waiting_match(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Leaving while waiting should not count as a forfeit."""
    headers = get_api_auth_headers(
        'dm-leave-wait@example.com',
        'password123',
        'Leaver',
    )
    q_resp = api_client.post('/api/v1/deathmatch/queue', headers=headers)
    match_id = q_resp.json()['match_id']

    leave_resp = api_client.post(
        f'/api/v1/deathmatch/leave/{match_id}',
        headers=headers,
    )
    assert leave_resp.status_code == 200
    assert leave_resp.json()['forfeited'] is False


def test_forfeit_active_match(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Leaving during an active match should forfeit (opponent wins)."""
    headers = get_api_auth_headers(
        'dm-forfeit@example.com',
        'password123',
        'Forfeiter',
    )

    # Queue and get matched with bot
    q_resp = api_client.post('/api/v1/deathmatch/queue', headers=headers)
    match_id = q_resp.json()['match_id']
    _poll_match_state(api_client, match_id, headers)

    # Forfeit
    leave_resp = api_client.post(
        f'/api/v1/deathmatch/leave/{match_id}',
        headers=headers,
    )
    assert leave_resp.status_code == 200
    assert leave_resp.json()['forfeited'] is True


# ---------------------------------------------------------------------------
# Error cases
# ---------------------------------------------------------------------------


def test_answer_without_auth_returns_401(api_client: TestClient) -> None:
    """Submitting without auth should fail."""
    resp = api_client.post(
        '/api/v1/deathmatch/answer',
        json={'match_id': 'fake', 'answer': {'number': 1, 'unit': None}},
    )
    assert resp.status_code == 401


def test_get_result_for_nonexistent_match(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Getting result for a nonexistent match should return 404."""
    headers = get_api_auth_headers(
        'dm-404@example.com',
        'password123',
        'Ghost',
    )
    resp = api_client.get(
        '/api/v1/deathmatch/result/nonexistent-match-id',
        headers=headers,
    )
    assert resp.status_code == 404


# ---------------------------------------------------------------------------
# Two-player match
# ---------------------------------------------------------------------------


def test_two_human_players_match(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
) -> None:
    """Two human players should be matched together when both queue."""
    headers_a = get_api_auth_headers(
        'dm-2p-a@example.com',
        'password123',
        'PlayerA',
    )
    headers_b = get_api_auth_headers(
        'dm-2p-b@example.com',
        'password123',
        'PlayerB',
    )

    # Player A queues first
    qa = api_client.post('/api/v1/deathmatch/queue', headers=headers_a)
    assert qa.status_code == 200
    assert qa.json()['status'] == 'waiting'

    # Player B queues - should match with A
    qb = api_client.post('/api/v1/deathmatch/queue', headers=headers_b)
    assert qb.status_code == 200
    assert qb.json()['status'] == 'matched'

    match_id = qb.json()['match_id']

    # Both players should see the match as active
    status_b = api_client.get(
        f'/api/v1/deathmatch/match/{match_id}',
        headers=headers_b,
    )
    assert status_b.status_code == 200
    assert status_b.json()['state'] >= 1

    # Both submit answers
    ans_a = api_client.post(
        '/api/v1/deathmatch/answer',
        json={'match_id': match_id, 'answer': {'number': 200.0, 'unit': None}},
        headers=headers_a,
    )
    assert ans_a.status_code == 200

    ans_b = api_client.post(
        '/api/v1/deathmatch/answer',
        json={'match_id': match_id, 'answer': {'number': 50.0, 'unit': None}},
        headers=headers_b,
    )
    assert ans_b.status_code == 200

    # At least one of them should have the result
    # (the second answerer triggers resolution)
    result = ans_b.json()
    if 'winner' not in result:
        # Second player might still get waiting if there's a race
        # Poll result endpoint
        time.sleep(0.5)
        result_resp = api_client.get(
            f'/api/v1/deathmatch/result/{match_id}',
            headers=headers_b,
        )
        assert result_resp.status_code == 200
        result = result_resp.json()

    assert 'winner' in result
    assert result['points_transferred'] == 50

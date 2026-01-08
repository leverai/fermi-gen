"""Integration tests for game bots feature.

Tests bot addition, automatic answer submission, and archiving exclusion.
"""

from __future__ import annotations

import time
import uuid
from collections.abc import Callable
from typing import Any

from fastapi.testclient import TestClient


def _wait_ready(
    get_firestore_doc: Callable[[str], dict[str, Any]],
    game_id: str,
    *,
    timeout_s: float = 8.0,
) -> dict[str, Any]:
    """Wait until game reaches LOBBY_READY state with questions populated."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc and doc.get('state') == 2 and doc.get('question_uids'):
            return doc
        time.sleep(0.1)
    raise AssertionError('Game did not become ready in time')


def _wait_started(
    get_firestore_doc: Callable[[str], dict[str, Any]],
    game_id: str,
    *,
    timeout_s: float = 8.0,
) -> dict[str, Any]:
    """Wait until game starts (QUESTION_N or QUESTION_LAST state)."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc and doc.get('state') in (3, 5):
            return doc
        time.sleep(0.1)
    raise AssertionError('Game did not start in time')


def _wait_all_answered(
    get_firestore_doc: Callable[[str], dict[str, Any]],
    game_id: str,
    *,
    timeout_s: float = 15.0,
) -> dict[str, Any]:
    """Wait until all players (including bots) have answered."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        progress = (doc.get('progress') or {}) if doc else {}
        if progress and progress.get('all_answered') is True:
            return doc
        time.sleep(0.1)
    raise AssertionError('Not all players answered in time')


def test_host_can_add_one_bot_to_lobby(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Host should be able to add 1 bot to a lobby game."""
    host_headers = get_api_auth_headers(
        'dev.user+bot-host-1@example.com',
        'password123',
        'BotHost1',
    )
    game_id = create_private_game(host_headers)
    _wait_ready(get_firestore_doc, game_id)

    # Add 1 bot
    resp = api_client.post(
        '/api/v1/game/add_bots',
        json={'resource_id': game_id, 'bot_ids': ['bot-gpt51']},
        headers=host_headers,
    )
    assert resp.status_code == 200

    # Verify bot was added to players
    time.sleep(0.5)  # Allow Firestore write to propagate
    doc = get_firestore_doc(game_id)
    players = doc.get('players', {})
    assert len(players) == 2  # 1 host + 1 bot
    bot_ids = [pid for pid in players if pid.startswith('bot-')]
    assert len(bot_ids) == 1  # Verify at least one bot was added


def test_host_can_add_three_bots_to_lobby(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Host should be able to add 3 bots to a lobby game."""
    host_headers = get_api_auth_headers(
        'dev.user+bot-host-3@example.com',
        'password123',
        'BotHost3',
    )
    game_id = create_private_game(host_headers)
    _wait_ready(get_firestore_doc, game_id)

    # Add 3 bots
    resp = api_client.post(
        '/api/v1/game/add_bots',
        json={
            'resource_id': game_id,
            'bot_ids': ['bot-gpt51', 'bot-gpt5mini', 'bot-gpt5nano'],
        },
        headers=host_headers,
    )
    assert resp.status_code == 200

    # Verify all 3 bots were added
    time.sleep(0.5)
    doc = get_firestore_doc(game_id)
    players = doc.get('players', {})
    assert len(players) == 4  # 1 host + 3 bots
    bot_ids = [pid for pid in players if pid.startswith('bot-')]
    assert len(bot_ids) == 3  # Verify all 3 bots were added


def test_non_host_cannot_add_bots(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Non-host player should not be able to add bots (403)."""
    host_headers = get_api_auth_headers(
        'dev.user+bot-host-403@example.com',
        'password123',
        'BotHost403',
    )
    joiner_headers = get_api_auth_headers(
        'dev.user+bot-joiner-403@example.com',
        'password123',
        'BotJoiner403',
    )
    game_id = create_private_game(host_headers)
    _wait_ready(get_firestore_doc, game_id)

    # Joiner joins the game
    api_client.post(
        '/api/v1/game/join',
        json={'resource_id': game_id},
        headers=joiner_headers,
    )
    _wait_ready(get_firestore_doc, game_id)

    # Joiner tries to add bots → 403
    resp = api_client.post(
        '/api/v1/game/add_bots',
        json={'resource_id': game_id, 'bot_ids': ['bot-gpt51']},
        headers=joiner_headers,
    )
    assert resp.status_code == 403


def test_cannot_add_bots_to_started_game(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Cannot add bots to a game that has already started (409)."""
    host_headers = get_api_auth_headers(
        'dev.user+bot-host-409@example.com',
        'password123',
        'BotHost409',
    )
    game_id = create_private_game(host_headers)
    _wait_ready(get_firestore_doc, game_id)

    # Start the game
    api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    _wait_started(get_firestore_doc, game_id)

    # Try to add bots after start → 409
    resp = api_client.post(
        '/api/v1/game/add_bots',
        json={'resource_id': game_id, 'bot_ids': ['bot-gpt51']},
        headers=host_headers,
    )
    assert resp.status_code == 409


def test_cannot_add_bots_exceeding_max_players(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
) -> None:
    """Cannot add bots if it would exceed max player limit (400)."""
    host_headers = get_api_auth_headers(
        'dev.user+bot-host-max@example.com',
        'password123',
        'BotHostMax',
    )
    game_id = create_private_game(host_headers)
    _wait_ready(get_firestore_doc, game_id)

    # Add 6 human players (host + 6 = 7 total)
    for i in range(6):
        headers = get_api_auth_headers(
            f'dev.user+bot-joiner-{i}@example.com',
            'password123',
            f'BotJoiner{i}',
        )
        api_client.post(
            '/api/v1/game/join',
            json={'resource_id': game_id},
            headers=headers,
        )
        # Wait for join to complete
        for _ in range(30):
            if len(get_firestore_doc(game_id).get('players', {})) >= (i + 2):
                break
            time.sleep(0.1)

    # Try to add 2 bots (would make 9 total, exceeding max of 8) → 400
    resp = api_client.post(
        '/api/v1/game/add_bots',
        json={'resource_id': game_id, 'bot_ids': ['bot-gpt51', 'bot-gpt5mini']},
        headers=host_headers,
    )
    assert resp.status_code == 400


# @pytest.mark.skip
def test_bot_answers_appear_in_players_results(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
    get_players_results_doc: Callable[[str, str], dict[str, Any]],
    get_answer_doc: Callable[[str, str], dict[str, Any]],
) -> None:
    """Bot answers should appear in players_results after question reveal."""
    host_headers = get_api_auth_headers(
        'dev.user+bot-host-answer@example.com',
        'password123',
        'BotHostAnswer',
    )
    game_id = create_private_game(host_headers, n_questions=1)
    _wait_ready(get_firestore_doc, game_id)

    # Add 2 bots
    api_client.post(
        '/api/v1/game/add_bots',
        json={'resource_id': game_id, 'bot_ids': ['bot-gpt51', 'bot-gemini1']},
        headers=host_headers,
    )
    time.sleep(0.5)

    # Start game
    api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    game_doc = _wait_started(get_firestore_doc, game_id)
    question_uid = game_doc['question_uid']

    # Query the correct answer to get the expected unit
    answer_doc = get_answer_doc(game_id, question_uid)
    expected_unit = answer_doc.get(
        'unit',
    )  # None for dimensionless, str for dimensional

    # Human submits answer with matching unit type
    api_client.post(
        '/api/v1/game/answer',
        json={'resource_id': game_id, 'answer': {'number': 100, 'unit': expected_unit}},
        headers=host_headers,
    )

    # Wait for bots to answer (background task)
    _wait_all_answered(get_firestore_doc, game_id)

    # Verify bot answers are in players_results
    time.sleep(1.0)  # Extra time for background task
    players_results = get_players_results_doc(game_id, question_uid)
    assert players_results, 'players_results document not found'

    results = players_results.get('players_results', {})
    # Should have 3 answers: 1 human + 2 bots
    assert len(results) == 3

    # Check bot answers exist
    bot_results = {pid: res for pid, res in results.items() if pid.startswith('bot-')}
    assert len(bot_results) == 2

    # Verify bot answers have expected structure
    for _bot_id, bot_result in bot_results.items():
        assert 'answer' in bot_result
        assert 'number' in bot_result['answer']
        assert 'score' in bot_result


def _wait_revealed(
    get_players_results_doc: Callable[[str, str], dict[str, Any]],
    game_id: str,
    question_uid: str,
    *,
    timeout_s: float = 10.0,
) -> dict[str, Any]:
    """Wait until players_results.revealed is True."""
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        doc = get_players_results_doc(game_id, question_uid)
        if doc and doc.get('revealed') is True:
            return doc
        time.sleep(0.1)
    raise AssertionError('players_results was not revealed in time')


def test_bot_last_to_answer_reveals_results(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
    get_players_results_doc: Callable[[str, str], dict[str, Any]],
    get_answer_doc: Callable[[str, str], dict[str, Any]],
) -> None:
    """When bot answers last, players_results.revealed should become True.

    This tests the fix for the bug where revealed=True was never set when
    a bot was the last player to answer, causing the frontend to remain
    stuck in a waiting state.
    """
    host_headers = get_api_auth_headers(
        'dev.user+bot-last-reveal@example.com',
        'password123',
        'BotLastReveal',
    )
    game_id = create_private_game(host_headers, n_questions=1)
    _wait_ready(get_firestore_doc, game_id)

    # Add 1 bot
    api_client.post(
        '/api/v1/game/add_bots',
        json={'resource_id': game_id, 'bot_ids': ['bot-gpt51']},
        headers=host_headers,
    )
    time.sleep(0.5)

    # Start game
    api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    game_doc = _wait_started(get_firestore_doc, game_id)
    question_uid = game_doc['question_uid']

    # Query the correct answer to get the expected unit
    answer_doc = get_answer_doc(game_id, question_uid)
    expected_unit = answer_doc.get('unit')

    # Human answers first (quickly before bots)
    api_client.post(
        '/api/v1/game/answer',
        json={'resource_id': game_id, 'answer': {'number': 100, 'unit': expected_unit}},
        headers=host_headers,
    )

    # Wait for bot to answer (bot will be last since human already answered)
    _wait_all_answered(get_firestore_doc, game_id)

    # Verify players_results is revealed (this is the key assertion)
    players_results = _wait_revealed(
        get_players_results_doc,
        game_id,
        question_uid,
        timeout_s=5.0,
    )
    assert players_results['revealed'] is True

    # Verify game state transitioned to finished
    game_doc = get_firestore_doc(game_id)
    # State 6 = QUESTION_LAST_FINISHED, State 8 = GAME_FINISHED
    # Both are valid - game may auto-finish after last question
    assert game_doc['state'] in (6, 8), (
        f'Expected state 6 or 8, got {game_doc["state"]}'
    )


# @pytest.mark.skip
def test_bot_answers_not_archived_to_answer_events(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
    get_answer_doc: Callable[[str, str], dict[str, Any]],
) -> None:
    """Bot answers should NOT be stored in answer_events table."""
    import asyncio
    import os

    from fermi_db.models.game import AnswerEvent
    from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
    from sqlmodel import select
    from sqlmodel.ext.asyncio.session import AsyncSession as SQLModelAsyncSession

    host_headers = get_api_auth_headers(
        'dev.user+bot-host-archive@example.com',
        'password123',
        'BotHostArchive',
    )
    game_id = create_private_game(host_headers, n_questions=1)
    _wait_ready(get_firestore_doc, game_id)

    # Add 2 bots
    api_client.post(
        '/api/v1/game/add_bots',
        json={'resource_id': game_id, 'bot_ids': ['bot-gpt51', 'bot-gemini1']},
        headers=host_headers,
    )
    time.sleep(0.5)

    # Start game and complete the round
    api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    game_doc = _wait_started(get_firestore_doc, game_id)
    question_uid = game_doc['question_uid']

    # Query the correct answer to get the expected unit
    answer_doc = get_answer_doc(game_id, question_uid)
    expected_unit = answer_doc.get(
        'unit',
    )  # None for dimensionless, str for dimensional

    # Human answers with matching unit type
    api_client.post(
        '/api/v1/game/answer',
        json={'resource_id': game_id, 'answer': {'number': 100, 'unit': expected_unit}},
        headers=host_headers,
    )

    # Wait for all to answer (human + bots)
    _wait_all_answered(get_firestore_doc, game_id)

    # Wait for game to finish (single question)
    deadline = time.time() + 10.0
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc.get('state') == 8:  # GAME_FINISHED
            break
        time.sleep(0.2)

    # Give extra time for archiving background task
    time.sleep(3.0)

    # Check answer_events table - fresh engine to avoid event loop issues
    async def _get_bot_answer_events_count(bot_user_id: str) -> int:
        dsn = os.environ['DATABASE_URL']
        engine = create_async_engine(dsn, echo=False)
        sess_maker = async_sessionmaker(
            engine,
            class_=SQLModelAsyncSession,
            expire_on_commit=False,
        )
        async with sess_maker() as session:
            result = await session.exec(
                select(AnswerEvent).where(
                    AnswerEvent.user_firebase_id == bot_user_id,  # type: ignore
                ),
            )
            count = len(list(result.all()))
        await engine.dispose()
        return count

    # Bot answers should NOT be archived
    bot_events_count = asyncio.run(_get_bot_answer_events_count('bot-gpt51'))
    assert bot_events_count == 0, 'Bot answers should not be in answer_events'


# @pytest.mark.skip
def test_bot_answers_not_added_to_user_history(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
    get_answer_doc: Callable[[str, str], dict[str, Any]],
) -> None:
    """Bot player IDs should NOT be added to user_question_history."""
    import asyncio
    import os

    from fermi_db.models.game import UserQuestionHistory
    from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
    from sqlmodel import select
    from sqlmodel.ext.asyncio.session import AsyncSession as SQLModelAsyncSession

    host_headers = get_api_auth_headers(
        'dev.user+bot-host-history@example.com',
        'password123',
        'BotHostHistory',
    )
    game_id = create_private_game(host_headers, n_questions=1)
    _wait_ready(get_firestore_doc, game_id)

    # Add 1 bot
    api_client.post(
        '/api/v1/game/add_bots',
        json={'resource_id': game_id, 'bot_ids': ['bot-gpt51']},
        headers=host_headers,
    )
    time.sleep(0.5)

    # Complete game
    api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    game_doc = _wait_started(get_firestore_doc, game_id)
    question_uid = game_doc['question_uid']

    # Query the correct answer to get the expected unit
    answer_doc = get_answer_doc(game_id, question_uid)
    expected_unit = answer_doc.get(
        'unit',
    )  # None for dimensionless, str for dimensional

    api_client.post(
        '/api/v1/game/answer',
        json={'resource_id': game_id, 'answer': {'number': 100, 'unit': expected_unit}},
        headers=host_headers,
    )
    _wait_all_answered(get_firestore_doc, game_id)

    # Wait for game end and archiving
    deadline = time.time() + 10.0
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc.get('state') == 8:
            break
        time.sleep(0.2)
    time.sleep(3.0)

    # Check user_question_history - fresh engine to avoid event loop issues
    async def _has_bot_seen_question(bot_user_id: str, q_uid: str) -> bool:
        dsn = os.environ['DATABASE_URL']
        engine = create_async_engine(dsn, echo=False)
        sess_maker = async_sessionmaker(
            engine,
            class_=SQLModelAsyncSession,
            expire_on_commit=False,
        )
        async with sess_maker() as session:
            result = await session.exec(
                select(UserQuestionHistory).where(
                    UserQuestionHistory.user_id == bot_user_id,  # type: ignore
                    UserQuestionHistory.question_uid == uuid.UUID(q_uid),  # type: ignore
                ),
            )
            has_seen = result.one_or_none() is not None
        await engine.dispose()
        return has_seen

    # Bot should NOT be in user_question_history
    bot_has_seen = asyncio.run(_has_bot_seen_question('bot-gpt51', question_uid))
    assert not bot_has_seen, 'Bot should not be in user_question_history'


# @pytest.mark.skip
def test_e2e_game_with_bots_completes_successfully(
    api_client: TestClient,
    get_api_auth_headers: Callable[[str, str, str], dict[str, str]],
    create_private_game: Callable[[dict[str, str]], str],
    get_firestore_doc: Callable[[str], dict[str, Any]],
    get_answer_doc: Callable[[str, str], dict[str, Any]],
) -> None:
    """End-to-end test: human plays full game with 2 bots."""
    host_headers = get_api_auth_headers(
        'dev.user+bot-e2e@example.com',
        'password123',
        'BotE2E',
    )
    game_id = create_private_game(host_headers, n_questions=2)  # type: ignore
    _wait_ready(get_firestore_doc, game_id)

    # Add 2 bots
    resp = api_client.post(
        '/api/v1/game/add_bots',
        json={'resource_id': game_id, 'bot_ids': ['bot-gpt51', 'bot-gemini1']},
        headers=host_headers,
    )
    assert resp.status_code == 200
    time.sleep(0.5)

    # Verify 3 players total
    doc = get_firestore_doc(game_id)
    assert len(doc['players']) == 3

    # Start game
    api_client.post(
        '/api/v1/game/start',
        json={'resource_id': game_id},
        headers=host_headers,
    )
    _wait_started(get_firestore_doc, game_id)

    # Play through 2 questions
    for round_num in range(2):
        # Get current question_uid and query the correct answer unit
        game_doc = get_firestore_doc(game_id)
        question_uid = game_doc['question_uid']
        answer_doc = get_answer_doc(game_id, question_uid)
        expected_unit = answer_doc.get(
            'unit',
        )  # None for dimensionless, str for dimensional

        # Human answers with matching unit type
        api_client.post(
            '/api/v1/game/answer',
            json={
                'resource_id': game_id,
                'answer': {'number': 100, 'unit': expected_unit},
            },
            headers=host_headers,
        )

        # Wait for bots to answer automatically
        _wait_all_answered(get_firestore_doc, game_id)

        # If not last round, advance to next question
        if round_num < 1:
            api_client.post(
                '/api/v1/game/next_question',
                json={'resource_id': game_id},
                headers=host_headers,
            )
            _wait_started(get_firestore_doc, game_id)

    # Wait for game to finish
    deadline = time.time() + 10.0
    while time.time() < deadline:
        doc = get_firestore_doc(game_id)
        if doc.get('state') == 8:  # GAME_FINISHED
            break
        time.sleep(0.2)
    else:
        raise AssertionError('Game did not finish')

    # Verify final scores include all players
    final_doc = get_firestore_doc(game_id)
    players = final_doc['players']
    assert len(players) == 3
    # All players should have scores
    for _player_id, player_data in players.items():
        assert 'score' in player_data
        assert isinstance(player_data['score'], int | float)

"""Unit tests for GameLifecycleWriter state transitions."""

# ruff: noqa: D103
from typing import TYPE_CHECKING, Any, cast

import pytest

from app.schemas.game import GameState
from app.services.game.errors import StateConflictError
from app.services.game.writers.lifecycle_writer import GameLifecycleWriter

if TYPE_CHECKING:
    from tests.unit.conftest import RecorderWriter


@pytest.mark.asyncio
async def test_set_ready_updates_state_to_lobby_ready(
    recorder_writer: 'RecorderWriter',
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GameLifecycleWriter()

    lw.set_ready(cast(Any, game_ref), cast(Any, writer))

    assert writer.updates == [(game_ref, {'state': GameState.LOBBY_READY})]


@pytest.mark.asyncio
async def test_start_game_in_lobby_ready_sets_started_and_state_question_n(
    recorder_writer: 'RecorderWriter',
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GameLifecycleWriter()

    lw.start_game(
        cast(Any, game_ref),
        cast(Any, writer),
        state=GameState.LOBBY_READY,
        n_questions=3,
    )

    assert len(writer.updates) == 1
    ref, data = writer.updates[0]
    assert ref is game_ref
    assert data['state'] == GameState.QUESTION_N
    assert 'started_at' in data


@pytest.mark.asyncio
async def test_start_game_single_question_sets_state_last(
    recorder_writer: 'RecorderWriter',
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GameLifecycleWriter()

    lw.start_game(
        cast(Any, game_ref),
        cast(Any, writer),
        state=GameState.LOBBY_READY,
        n_questions=1,
    )
    assert writer.updates[0][1]['state'] == GameState.QUESTION_LAST


@pytest.mark.asyncio
async def test_start_game_invalid_state_raises_conflict(
    recorder_writer: 'RecorderWriter',
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GameLifecycleWriter()

    with pytest.raises(StateConflictError):
        lw.start_game(
            cast(Any, game_ref),
            cast(Any, writer),
            state=GameState.LOBBY_NOT_READY,
            n_questions=2,
        )


@pytest.mark.asyncio
async def test_end_game_from_last_finished_sets_finished_and_returns_started_true(
    recorder_writer: 'RecorderWriter',
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GameLifecycleWriter()

    started = lw.end_game(
        cast(Any, game_ref),
        cast(Any, writer),
        current_state=GameState.QUESTION_LAST_FINISHED,
    )

    assert started is True
    assert writer.updates[0][1]['state'] == GameState.GAME_FINISHED
    assert 'ended_at' in writer.updates[0][1]


@pytest.mark.asyncio
async def test_end_game_from_pre_start_sets_aborted_and_returns_started_false(
    recorder_writer: 'RecorderWriter',
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GameLifecycleWriter()

    started = lw.end_game(
        cast(Any, game_ref),
        cast(Any, writer),
        current_state=GameState.LOBBY_READY,
    )

    assert started is False
    assert writer.updates[0][1]['state'] == GameState.GAME_ABORTED


@pytest.mark.asyncio
async def test_end_game_already_finished_raises_conflict(
    recorder_writer: 'RecorderWriter',
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GameLifecycleWriter()

    with pytest.raises(StateConflictError):
        lw.end_game(
            cast(Any, game_ref),
            cast(Any, writer),
            current_state=GameState.GAME_FINISHED,
        )


@pytest.mark.asyncio
async def test_next_question_happy_path_advances_and_sets_state(
    recorder_writer: 'RecorderWriter',
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GameLifecycleWriter()

    next_idx = lw.next_question(
        cast(Any, game_ref),
        cast(Any, writer),
        state=GameState.QUESTION_N_FINISHED,
        question_order=0,
        n_questions=3,
    )

    assert next_idx == 1
    # With 3 total and moving to index 1, still QUESTION_N
    assert writer.updates[0][1]['state'] == GameState.QUESTION_N


@pytest.mark.asyncio
async def test_next_question_sets_last_when_advancing_to_final(
    recorder_writer: 'RecorderWriter',
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GameLifecycleWriter()

    next_idx = lw.next_question(
        cast(Any, game_ref),
        cast(Any, writer),
        state=GameState.QUESTION_N_FINISHED,
        question_order=1,
        n_questions=2,
    )

    assert next_idx == 2
    assert writer.updates[0][1]['state'] == GameState.QUESTION_LAST


@pytest.mark.asyncio
async def test_next_question_invalid_state_raises_conflict(
    recorder_writer: 'RecorderWriter',
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GameLifecycleWriter()

    with pytest.raises(StateConflictError):
        lw.next_question(
            cast(Any, game_ref),
            cast(Any, writer),
            state=GameState.QUESTION_N,
            question_order=0,
            n_questions=2,
        )


@pytest.mark.asyncio
async def test_join_game_in_lobby_keeps_lobby_ready(
    recorder_writer: 'RecorderWriter',
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GameLifecycleWriter()

    lw.join_game(cast(Any, game_ref), cast(Any, writer), state=GameState.LOBBY_READY)
    assert writer.updates[0][1]['state'] == GameState.LOBBY_READY


@pytest.mark.asyncio
async def test_join_game_invalid_state_raises_conflict(
    recorder_writer: 'RecorderWriter',
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GameLifecycleWriter()

    with pytest.raises(StateConflictError):
        lw.join_game(cast(Any, game_ref), cast(Any, writer), state=GameState.QUESTION_N)


@pytest.mark.asyncio
async def test_finish_question_transitions_correctly_from_question_n(
    recorder_writer: 'RecorderWriter',
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GameLifecycleWriter()

    next_state = lw.finish_question(
        cast(Any, game_ref),
        cast(Any, writer),
        state=GameState.QUESTION_N,
    )

    assert next_state == GameState.QUESTION_N_FINISHED
    assert writer.updates[0][1]['state'] == GameState.QUESTION_N_FINISHED


@pytest.mark.asyncio
async def test_finish_question_transitions_correctly_from_question_last(
    recorder_writer: 'RecorderWriter',
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GameLifecycleWriter()

    next_state = lw.finish_question(
        cast(Any, game_ref),
        cast(Any, writer),
        state=GameState.QUESTION_LAST,
    )

    assert next_state == GameState.QUESTION_LAST_FINISHED
    assert writer.updates[0][1]['state'] == GameState.QUESTION_LAST_FINISHED


@pytest.mark.asyncio
async def test_finish_question_invalid_state_raises_conflict(
    recorder_writer: 'RecorderWriter',
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GameLifecycleWriter()

    with pytest.raises(StateConflictError):
        lw.finish_question(
            cast(Any, game_ref),
            cast(Any, writer),
            state=GameState.LOBBY_READY,
        )

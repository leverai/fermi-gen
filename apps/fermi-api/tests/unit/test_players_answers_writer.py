"""Unit tests for GamePlayersAnswersWriter operations."""

# ruff: noqa: D103, FBT001, FBT002
from typing import Any, cast

import pytest
from google.cloud import firestore
from tests.unit.conftest import RecorderWriter

from app.services.game.errors import NotFoundError, StateConflictError
from app.services.game.writers.players_answers_writer import (
    GamePlayersAnswersWriter,
)


class _FakePlayersResultsCollection:
    def __init__(self) -> None:
        self._docs: dict[str, object] = {}

    def document(self, doc_id: str) -> object:
        # Return a lightweight object representing a document reference
        ref = object()
        self._docs[doc_id] = ref
        return ref


class _FakeGameRef:
    def __init__(self) -> None:
        self._collections: dict[str, _FakePlayersResultsCollection] = {}

    def collection(self, name: str) -> _FakePlayersResultsCollection:
        if name not in self._collections:
            self._collections[name] = _FakePlayersResultsCollection()
        return self._collections[name]


def _progress_map(
    answered_by: dict[str, bool],
    all_answered: bool = False,
) -> dict:
    return {'progress': {'answered': answered_by, 'all_answered': all_answered}}


@pytest.fixture
def fake_game_ref() -> _FakeGameRef:
    return _FakeGameRef()


def test_init_players_results_docs_creates_docs(
    recorder_writer: RecorderWriter,
    fake_game_ref: _FakeGameRef,
) -> None:
    gw = GamePlayersAnswersWriter()
    qids = ['q1', 'q2', 'q3']

    gw.init_players_results_docs(
        cast(Any, fake_game_ref),
        cast(Any, recorder_writer),
        qids,
    )

    assert len(recorder_writer.sets) == 3
    # Validate a representative payload shape
    _, data = recorder_writer.sets[0]
    assert data['question_uid'] in qids
    assert data['players_results'] == {}
    assert data['revealed'] is False


def test_init_progress_builds_answered_map(
    recorder_writer: RecorderWriter,
    fake_game_ref: _FakeGameRef,
) -> None:
    gw = GamePlayersAnswersWriter()

    gw.init_progress(
        cast(Any, fake_game_ref),
        cast(Any, recorder_writer),
        players_ids=['a', 'b'],
    )

    assert len(recorder_writer.updates) == 1
    _, data = recorder_writer.updates[0]
    assert set(data['progress']['answered'].keys()) == {'a', 'b'}
    assert all(v is False for v in data['progress']['answered'].values())
    assert data['progress']['all_answered'] is False


def test_submit_answer_happy_path_updates_results_and_progress(
    monkeypatch: pytest.MonkeyPatch,
    recorder_writer: RecorderWriter,
) -> None:
    gw = GamePlayersAnswersWriter()
    fake_game_ref = _FakeGameRef()

    # Stub scoring methods for determinism
    monkeypatch.setattr(
        gw._scoring_service,
        'calculate_score',
        lambda **_: 42.0,
    )
    monkeypatch.setattr(
        gw._scoring_service,
        'get_score_quantile',
        lambda **_: 0.75,
    )

    progress = cast(
        Any,
        {'answered': {'u1': False, 'u2': True}, 'all_answered': False},
    )
    correct_doc = cast(Any, {'number': 1000.0, 'unit': None, 'quantiles': {}})
    answer = cast(Any, {'number': 1000.0, 'unit': None})

    all_answered, score = gw.submit_answer(
        cast(Any, fake_game_ref),
        cast(Any, recorder_writer),
        player_id='u1',
        question_uid='q1',
        answer=answer,
        correct_answer_doc=correct_doc,
        progress=progress,
    )

    # players_results updated
    assert any(
        'players_results.u1' in next(iter(update[1].keys()))
        for update in recorder_writer.updates
    )
    # progress updated and all_answered becomes True because u2 was already True
    assert {k for _, d in recorder_writer.updates for k in d.keys()} >= {
        'progress.all_answered',
        'progress.answered.u1',
    }
    assert all_answered is True
    assert score == 42.0


def test_submit_answer_not_tracked_raises(
    monkeypatch: pytest.MonkeyPatch,
    recorder_writer: RecorderWriter,
) -> None:
    gw = GamePlayersAnswersWriter()
    fake_game_ref = _FakeGameRef()

    progress = cast(Any, {'answered': {'u2': False}, 'all_answered': False})
    correct_doc = cast(Any, {'number': 1.0, 'unit': None, 'quantiles': {}})
    answer = cast(Any, {'number': 1.0, 'unit': None})

    with pytest.raises(NotFoundError):
        gw.submit_answer(
            cast(Any, fake_game_ref),
            cast(Any, recorder_writer),
            player_id='u1',
            question_uid='q1',
            answer=answer,
            correct_answer_doc=correct_doc,
            progress=progress,
        )


def test_submit_answer_duplicate_raises(
    monkeypatch: pytest.MonkeyPatch,
    recorder_writer: RecorderWriter,
) -> None:
    gw = GamePlayersAnswersWriter()
    fake_game_ref = _FakeGameRef()

    progress = cast(Any, {'answered': {'u1': True}, 'all_answered': False})
    correct_doc = cast(Any, {'number': 1.0, 'unit': None, 'quantiles': {}})
    answer = cast(Any, {'number': 1.0, 'unit': None})

    with pytest.raises(StateConflictError):
        gw.submit_answer(
            cast(Any, fake_game_ref),
            cast(Any, recorder_writer),
            player_id='u1',
            question_uid='q1',
            answer=answer,
            correct_answer_doc=correct_doc,
            progress=progress,
        )


def test_reveal_players_results_sets_flag(
    recorder_writer: RecorderWriter,
    fake_game_ref: _FakeGameRef,
) -> None:
    gw = GamePlayersAnswersWriter()

    gw.reveal_players_results(
        cast(Any, fake_game_ref),
        cast(Any, recorder_writer),
        question_uid='q1',
    )

    assert len(recorder_writer.updates) == 1
    _, data = recorder_writer.updates[0]
    assert data == {'revealed': True}


def test_remove_player_pending_recomputes_all_answered(
    recorder_writer: RecorderWriter,
    fake_game_ref: _FakeGameRef,
) -> None:
    gw = GamePlayersAnswersWriter()
    progress = cast(Any, {'answered': {'a': False, 'b': True}, 'all_answered': False})

    all_answered = gw.remove_player(
        cast(Any, fake_game_ref),
        cast(Any, recorder_writer),
        remove_id='a',
        progress=progress,
    )

    assert all_answered is True
    # Should delete answered flag for 'a' and set all_answered
    assert recorder_writer.updates[0][1] == {
        'progress.answered.a': firestore.DELETE_FIELD,
        'progress.all_answered': True,
    }


def test_remove_player_non_tracked_raises(
    recorder_writer: RecorderWriter,
    fake_game_ref: _FakeGameRef,
) -> None:
    gw = GamePlayersAnswersWriter()
    progress = cast(Any, {'answered': {'a': False}, 'all_answered': False})

    with pytest.raises(NotFoundError):
        gw.remove_player(
            cast(Any, fake_game_ref),
            cast(Any, recorder_writer),
            remove_id='z',
            progress=progress,
        )


def test_remove_player_already_answered_no_update(
    recorder_writer: RecorderWriter,
    fake_game_ref: _FakeGameRef,
) -> None:
    gw = GamePlayersAnswersWriter()
    progress = cast(Any, {'answered': {'a': True, 'b': True}, 'all_answered': True})

    all_answered = gw.remove_player(
        cast(Any, fake_game_ref),
        cast(Any, recorder_writer),
        remove_id='a',
        progress=progress,
    )

    assert all_answered is True
    # No update recorded when the removed player had already answered
    assert recorder_writer.updates == []

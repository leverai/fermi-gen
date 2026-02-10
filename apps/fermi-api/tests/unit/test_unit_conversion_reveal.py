"""Unit tests for unit conversion at reveal event."""

# ruff: noqa: D103
from typing import Any, cast

import pytest
from fermi_db.schemas import AnswerBare
from tests.unit.conftest import RecorderWriter

from app.schemas.game import PlayerResult, PlayersResultsDoc
from app.services.game.writers.players_answers_writer import (
    GamePlayersAnswersWriter,
)


class _FakePlayersResultsCollection:
    def __init__(self) -> None:
        self._docs: dict[str, object] = {}

    def document(self, doc_id: str) -> object:
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


@pytest.fixture
def fake_game_ref() -> _FakeGameRef:
    return _FakeGameRef()


def test_reveal_converts_dimensional_answers_to_each_players_unit(
    recorder_writer: RecorderWriter,
    fake_game_ref: _FakeGameRef,
) -> None:
    """Test that dimensional answers are converted to each player's unit."""
    gw = GamePlayersAnswersWriter()

    # Player 1 answered in kilograms (already in doc), Player 2 in pounds (current
    # player)
    players_results_doc = cast(
        PlayersResultsDoc,
        {
            'question_uid': 'q1',
            'players_results': {
                'player1': PlayerResult(
                    answer=AnswerBare(number=100.0, unit='kilogram'),
                    correct_answer=AnswerBare(number=150.0, unit='kilogram'),
                    score={'number': 85.0, 'quantile': 0.75},
                    converted_answers={},  # Will be populated
                ),
            },
            'revealed': False,
        },
    )

    # Current player (player2) - passed separately to simulate read-before-write
    current_player_result = PlayerResult(
        answer=AnswerBare(number=220.0, unit='pound'),
        correct_answer=AnswerBare(number=330.0, unit='pound'),
        score={'number': 85.0, 'quantile': 0.75},
        converted_answers={},
    )

    gw.reveal_players_results(
        cast(Any, fake_game_ref),
        cast(Any, recorder_writer),
        question_uid='q1',
        players_results_doc=players_results_doc,
        current_player_id='player2',
        current_player_result=current_player_result,
    )

    # Check that update was called
    assert len(recorder_writer.updates) == 1
    _, update_data = recorder_writer.updates[0]

    # Player 1 should see Player 2's answer converted to kilograms
    player1_converted = update_data['players_results.player1.converted_answers']
    assert 'player2' in player1_converted
    # 220 pounds ≈ 99.79 kg
    assert player1_converted['player2']['unit'] == 'kilogram'
    assert abs(player1_converted['player2']['number'] - 99.79) < 0.1

    # Player 2 should see Player 1's answer converted to pounds
    player2_converted = update_data['players_results.player2.converted_answers']
    assert 'player1' in player2_converted
    # 100 kg ≈ 220.46 pounds
    assert player2_converted['player1']['unit'] == 'pound'
    assert abs(player2_converted['player1']['number'] - 220.46) < 0.1

    # Revealed should be set to True
    assert update_data['revealed'] is True


def test_reveal_handles_dimensionless_questions(
    recorder_writer: RecorderWriter,
    fake_game_ref: _FakeGameRef,
) -> None:
    """Test that dimensionless questions work correctly (no conversion)."""
    gw = GamePlayersAnswersWriter()

    # Player 1 in doc, Player 2 is current player (both dimensionless)
    players_results_doc = cast(
        PlayersResultsDoc,
        {
            'question_uid': 'q2',
            'players_results': {
                'player1': PlayerResult(
                    answer=AnswerBare(number=1000.0, unit=None),
                    correct_answer=AnswerBare(number=1500.0, unit=None),
                    score={'number': 90.0, 'quantile': 0.85},
                    converted_answers={},
                ),
            },
            'revealed': False,
        },
    )

    current_player_result = PlayerResult(
        answer=AnswerBare(number=2000.0, unit=None),
        correct_answer=AnswerBare(number=1500.0, unit=None),
        score={'number': 75.0, 'quantile': 0.65},
        converted_answers={},
    )

    gw.reveal_players_results(
        cast(Any, fake_game_ref),
        cast(Any, recorder_writer),
        question_uid='q2',
        players_results_doc=players_results_doc,
        current_player_id='player2',
        current_player_result=current_player_result,
    )

    assert len(recorder_writer.updates) == 1
    _, update_data = recorder_writer.updates[0]

    # Player 1 should see Player 2's answer unchanged
    player1_converted = update_data['players_results.player1.converted_answers']
    assert player1_converted['player2']['number'] == 2000.0
    assert player1_converted['player2']['unit'] is None

    # Player 2 should see Player 1's answer unchanged
    player2_converted = update_data['players_results.player2.converted_answers']
    assert player2_converted['player1']['number'] == 1000.0
    assert player2_converted['player1']['unit'] is None

    assert update_data['revealed'] is True


def test_reveal_handles_same_unit(
    recorder_writer: RecorderWriter,
    fake_game_ref: _FakeGameRef,
) -> None:
    """Test that players with the same unit see correct conversions."""
    gw = GamePlayersAnswersWriter()

    # Player 1 in doc, Player 2 is current player (both meters)
    players_results_doc = cast(
        PlayersResultsDoc,
        {
            'question_uid': 'q3',
            'players_results': {
                'player1': PlayerResult(
                    answer=AnswerBare(number=100.0, unit='meter'),
                    correct_answer=AnswerBare(number=150.0, unit='meter'),
                    score={'number': 85.0, 'quantile': 0.75},
                    converted_answers={},
                ),
            },
            'revealed': False,
        },
    )

    current_player_result = PlayerResult(
        answer=AnswerBare(number=200.0, unit='meter'),
        correct_answer=AnswerBare(number=150.0, unit='meter'),
        score={'number': 75.0, 'quantile': 0.65},
        converted_answers={},
    )

    gw.reveal_players_results(
        cast(Any, fake_game_ref),
        cast(Any, recorder_writer),
        question_uid='q3',
        players_results_doc=players_results_doc,
        current_player_id='player2',
        current_player_result=current_player_result,
    )

    assert len(recorder_writer.updates) == 1
    _, update_data = recorder_writer.updates[0]

    # Both should see each other's answers in meters (no conversion needed)
    player1_converted = update_data['players_results.player1.converted_answers']
    assert player1_converted['player2']['number'] == 200.0
    assert player1_converted['player2']['unit'] == 'meter'

    player2_converted = update_data['players_results.player2.converted_answers']
    assert player2_converted['player1']['number'] == 100.0
    assert player2_converted['player1']['unit'] == 'meter'


def test_reveal_handles_multiple_players(
    recorder_writer: RecorderWriter,
    fake_game_ref: _FakeGameRef,
) -> None:
    """Test conversion with more than 2 players."""
    gw = GamePlayersAnswersWriter()

    # Players 1 & 2 in doc, Player 3 is current player (different units)
    players_results_doc = cast(
        PlayersResultsDoc,
        {
            'question_uid': 'q4',
            'players_results': {
                'player1': PlayerResult(
                    answer=AnswerBare(number=1000.0, unit='meter'),
                    correct_answer=AnswerBare(number=1500.0, unit='meter'),
                    score={'number': 85.0, 'quantile': 0.75},
                    converted_answers={},
                ),
                'player2': PlayerResult(
                    answer=AnswerBare(number=3280.0, unit='foot'),
                    correct_answer=AnswerBare(number=4921.0, unit='foot'),
                    score={'number': 85.0, 'quantile': 0.75},
                    converted_answers={},
                ),
            },
            'revealed': False,
        },
    )

    current_player_result = PlayerResult(
        answer=AnswerBare(number=1.0, unit='kilometer'),
        correct_answer=AnswerBare(number=1.5, unit='kilometer'),
        score={'number': 85.0, 'quantile': 0.75},
        converted_answers={},
    )

    gw.reveal_players_results(
        cast(Any, fake_game_ref),
        cast(Any, recorder_writer),
        question_uid='q4',
        players_results_doc=players_results_doc,
        current_player_id='player3',
        current_player_result=current_player_result,
    )

    assert len(recorder_writer.updates) == 1
    _, update_data = recorder_writer.updates[0]

    # Each player should see conversions for the other 2 players
    player1_converted = update_data['players_results.player1.converted_answers']
    assert len(player1_converted) == 2
    assert 'player2' in player1_converted
    assert 'player3' in player1_converted
    assert player1_converted['player2']['unit'] == 'meter'
    assert player1_converted['player3']['unit'] == 'meter'

    player2_converted = update_data['players_results.player2.converted_answers']
    assert len(player2_converted) == 2
    assert 'player1' in player2_converted
    assert 'player3' in player2_converted
    assert player2_converted['player1']['unit'] == 'foot'
    assert player2_converted['player3']['unit'] == 'foot'

    player3_converted = update_data['players_results.player3.converted_answers']
    assert len(player3_converted) == 2
    assert 'player1' in player3_converted
    assert 'player2' in player3_converted
    assert player3_converted['player1']['unit'] == 'kilometer'
    assert player3_converted['player2']['unit'] == 'kilometer'

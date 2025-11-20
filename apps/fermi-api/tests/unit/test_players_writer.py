"""Unit tests for GamePlayersWriter operations."""

# ruff: noqa: D103
from typing import Any, cast

import pytest
from google.cloud import firestore
from tests.unit.conftest import RecorderWriter

from app.schemas.game import GamePlayer, GameState
from app.services.game.errors import NotFoundError, StateConflictError, ValidationError
from app.services.game.writers.players_writer import GamePlayersWriter

# no additional aliases needed


def _user(uid: str, name: str = 'n', picture: str | None = None) -> object:
    from types import SimpleNamespace

    return SimpleNamespace(firebase_uid=uid, display_name=name, picture=picture)


def _players_map(*uids: str, host: str | None = None) -> dict[str, GamePlayer]:
    lw = GamePlayersWriter()
    players: dict[str, GamePlayer] = {}
    for uid in uids:
        players[uid] = lw._user_to_player(_user(uid), is_host=(uid == host))  # type: ignore[attr-defined]
    return players


def test_set_players_happy_path_sets_players_host_and_full_flag(
    recorder_writer: RecorderWriter,
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GamePlayersWriter()

    users = [_user('a'), _user('b')]
    lw.set_players(
        cast(Any, game_ref),
        cast(Any, writer),
        host_id='a',
        users=cast(Any, users),
    )

    assert len(writer.updates) == 1
    _, data = writer.updates[0]
    assert data['host'] == 'a'
    assert set(data['players'].keys()) == {'a', 'b'}
    assert data['players']['a']['is_host'] is True
    assert data['players']['b']['is_host'] is False
    assert data['full'] is False


def test_set_players_validates_host_present(
    recorder_writer: RecorderWriter,
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GamePlayersWriter()
    with pytest.raises(ValidationError):
        lw.set_players(
            cast(Any, game_ref),
            cast(Any, writer),
            host_id='z',
            users=cast(Any, [_user('a')]),
        )


def test_set_players_validates_max_players(
    recorder_writer: RecorderWriter,
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GamePlayersWriter()
    users = [_user(str(i)) for i in range(1, 10)]  # 9 > MAX_PLAYERS(8)
    with pytest.raises(ValidationError):
        lw.set_players(
            cast(Any, game_ref),
            cast(Any, writer),
            host_id='1',
            users=cast(Any, users),
        )


def test_add_player_adds_and_sets_full_flag(
    recorder_writer: RecorderWriter,
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GamePlayersWriter()
    players = _players_map('1', '2', '3', '4', '5', '6', '7')

    uid_list = lw.add_player(
        cast(Any, game_ref),
        cast(Any, writer),
        players=cast(Any, players),
        user=cast(Any, _user('8')),
    )

    assert uid_list[-1] == '8'
    # With 7 existing, adding the 8th should set full=True
    assert writer.updates[0][1]['full'] is True


def test_add_player_duplicate_raises_conflict(
    recorder_writer: RecorderWriter,
    fake_doc_ref: object,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GamePlayersWriter()
    players = _players_map('1')

    with pytest.raises(StateConflictError):
        lw.add_player(
            cast(Any, game_ref),
            cast(Any, writer),
            players=cast(Any, players),
            user=cast(Any, _user('1')),
        )


def test_get_active_player_ids_filters_inactive(players_map_factory: Any) -> None:
    lw = GamePlayersWriter()
    players = players_map_factory('a', 'b', host='a')
    players['b']['is_active'] = False
    assert lw.get_active_player_ids(players) == ['a']


def test_remove_player_in_lobby_deletes_doc_and_updates_full_and_host(
    recorder_writer: RecorderWriter,
    fake_doc_ref: object,
    players_map_factory: Any,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GamePlayersWriter()
    players = players_map_factory('a', 'b', 'c', host='a')

    active = lw.remove_player(
        cast(Any, game_ref),
        cast(Any, writer),
        players=players,
        remove_id='a',
        state=GameState.LOBBY_READY,
        is_host=True,
    )

    assert active == ['b', 'c']
    # First update marks deletion of player a;
    # second clears 'full';
    # third reassigns host
    assert writer.updates[0][1] == {'players.a': firestore.DELETE_FIELD}
    assert writer.updates[1][1] == {'full': False}
    assert writer.updates[2][1] == {'host': 'b'}


def test_remove_player_in_game_marks_inactive_and_updates_full(
    recorder_writer: RecorderWriter,
    fake_doc_ref: object,
    players_map_factory: Any,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GamePlayersWriter()
    players = players_map_factory('a', 'b', host='a')

    active = lw.remove_player(
        cast(Any, game_ref),
        cast(Any, writer),
        players=players,
        remove_id='b',
        state=GameState.QUESTION_N,
        is_host=True,
    )

    assert active == ['a']
    # First update flags inactive;
    # second clears 'full';
    # third reassigns host remains 'a'
    assert writer.updates[0][1] == {'players.b.is_active': False}
    assert writer.updates[1][1] == {'full': False}
    assert writer.updates[2][1] == {'host': 'a'}


def test_remove_player_not_found_raises(
    recorder_writer: RecorderWriter,
    fake_doc_ref: object,
    players_map_factory: Any,
) -> None:
    writer = recorder_writer
    game_ref = fake_doc_ref
    lw = GamePlayersWriter()
    players = players_map_factory('a', 'b', host='a')
    players['b']['is_active'] = False

    with pytest.raises(NotFoundError):
        lw.remove_player(
            cast(Any, game_ref),
            cast(Any, writer),
            players=players,
            remove_id='b',
            state=GameState.LOBBY_READY,
            is_host=False,
        )

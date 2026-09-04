"""Regression tests for roster mutations racing an in-flight game start."""

# ruff: noqa: D103
from types import SimpleNamespace
from typing import Any, cast

import pytest
from fastapi import HTTPException

from app.schemas.game import GameState
from app.services.game.use_cases.add_bots import AddBotsUseCase
from app.services.game.use_cases.join_game import JoinGameUseCase
from app.services.game.use_cases.remove_player import RemovePlayerUseCase
from app.services.game.writers.lifecycle_writer import GameLifecycleWriter


class _Recorder:
    def __init__(self) -> None:
        self.updates: list[tuple[Any, dict]] = []

    def update(self, ref: Any, data: dict) -> None:
        self.updates.append((ref, data))


class _Runner:
    def __init__(self, tx: _Recorder) -> None:
        self.tx = tx

    async def run(self, func: Any) -> Any:
        return await func(self.tx)


class _Client:
    def collection(self, _name: str) -> Any:
        return SimpleNamespace(
            document=lambda game_id: SimpleNamespace(id=game_id),
        )


class _Repo:
    async def get_game_fields(self, *_args: Any, **_kwargs: Any) -> dict:
        return {
            'host': 'host-1',
            'players': {'host-1': {'is_active': True}},
            'state': int(GameState.LOBBY_READY),
            'full': False,
            'max_players': 5,
            'progress': {},
            'question_uid': None,
            'start_claim_id': 'claim-1',
        }


@pytest.mark.asyncio
async def test_join_is_rejected_after_start_claim() -> None:
    tx = _Recorder()
    use_case = JoinGameUseCase(
        firestore_client=cast(Any, _Client()),
        txn_runner=cast(Any, _Runner(tx)),
        repo=cast(Any, _Repo()),
        lifecycle=GameLifecycleWriter(),
        players=cast(Any, SimpleNamespace()),
    )

    with pytest.raises(HTTPException) as exc_info:
        await use_case.execute(
            game_id='game-1',
            current_user=cast(Any, SimpleNamespace(firebase_uid='player-2')),
        )

    assert exc_info.value.status_code == 409
    assert tx.updates == []


@pytest.mark.asyncio
async def test_add_bots_is_rejected_after_start_claim() -> None:
    tx = _Recorder()
    use_case = AddBotsUseCase(
        firestore_client=cast(Any, _Client()),
        txn_runner=cast(Any, _Runner(tx)),
        repo=cast(Any, _Repo()),
        lifecycle=GameLifecycleWriter(),
    )

    with pytest.raises(HTTPException) as exc_info:
        await use_case.execute(
            request=cast(Any, SimpleNamespace(base_url='http://test/')),
            game_id='game-1',
            current_user=cast(Any, SimpleNamespace(firebase_uid='host-1')),
            bot_ids=['bot-gpt51'],
        )

    assert exc_info.value.status_code == 409
    assert tx.updates == []


@pytest.mark.asyncio
async def test_remove_player_is_rejected_after_start_claim() -> None:
    tx = _Recorder()
    use_case = RemovePlayerUseCase(
        firestore_client=cast(Any, _Client()),
        txn_runner=cast(Any, _Runner(tx)),
        repo=cast(Any, _Repo()),
        lifecycle=GameLifecycleWriter(),
        players=cast(Any, SimpleNamespace()),
        players_answers=cast(Any, SimpleNamespace()),
        questions=cast(Any, SimpleNamespace()),
    )

    with pytest.raises(HTTPException) as exc_info:
        await use_case.execute(
            game_id='game-1',
            actor_user=cast(Any, SimpleNamespace(firebase_uid='host-1')),
            remove_player_id='host-1',
        )

    assert exc_info.value.status_code == 409
    assert tx.updates == []

"""Firestore-emulator regression for a join racing the start claim."""

from __future__ import annotations

import asyncio
import os
import uuid
from typing import TYPE_CHECKING, Any, cast

import pytest
from fastapi import HTTPException
from fermi_db.models.user import User
from google.cloud import firestore

from app.schemas.game import GameState
from app.services.game.repositories.game_repo import GameRepository
from app.services.game.transactions.runner import TransactionRunner
from app.services.game.use_cases.join_game import JoinGameUseCase
from app.services.game.use_cases.start_game import StartGameUseCase
from app.services.game.writers.lifecycle_writer import GameLifecycleWriter
from app.services.game.writers.players_writer import GamePlayersWriter

if TYPE_CHECKING:
    from google.cloud.firestore_v1 import AsyncDocumentReference, AsyncTransaction


class _CoordinatedGameRepository(GameRepository):
    """Pause before the first claim read so a concurrent join can commit."""

    def __init__(
        self,
        client: firestore.AsyncClient,
        *,
        claim_waiting: asyncio.Event,
        allow_claim: asyncio.Event,
    ) -> None:
        super().__init__(client)
        self._claim_waiting = claim_waiting
        self._allow_claim = allow_claim
        self.claim_read_attempts = 0

    async def get_game_fields(
        self,
        game_ref: AsyncDocumentReference,
        *,
        fields: list[str] | None = None,
        tx: AsyncTransaction | None = None,
    ) -> dict[str, Any]:
        if fields and 'start_claim_id' in fields and 'n_questions' in fields:
            self.claim_read_attempts += 1
            if self.claim_read_attempts == 1:
                self._claim_waiting.set()
                await self._allow_claim.wait()
        return await super().get_game_fields(game_ref, fields=fields, tx=tx)


class _PostReadCoordinatedGameRepository(GameRepository):
    """Pause one transaction after its first document read."""

    def __init__(
        self,
        client: firestore.AsyncClient,
        *,
        marker_field: str,
        read_complete: asyncio.Event,
        allow_return: asyncio.Event,
    ) -> None:
        super().__init__(client)
        self._marker_field = marker_field
        self._read_complete = read_complete
        self._allow_return = allow_return
        self.read_attempts = 0

    async def get_game_fields(
        self,
        game_ref: AsyncDocumentReference,
        *,
        fields: list[str] | None = None,
        tx: AsyncTransaction | None = None,
    ) -> dict[str, Any]:
        data = await super().get_game_fields(game_ref, fields=fields, tx=tx)
        if fields and self._marker_field in fields:
            self.read_attempts += 1
            if self.read_attempts == 1:
                self._read_complete.set()
                await self._allow_return.wait()
        return data


class _SignalingPlayersWriter:
    """Signal once the join callback has queued its transactional write."""

    def __init__(self, write_queued: asyncio.Event) -> None:
        self._delegate = GamePlayersWriter()
        self._write_queued = write_queued

    def add_player(self, **kwargs: Any) -> list[str]:
        result = self._delegate.add_player(**kwargs)
        self._write_queued.set()
        return result


def _lobby_data(host: User) -> dict[str, Any]:
    return {
        'host': host.firebase_uid,
        'players': {
            host.firebase_uid: {
                'player_id': host.firebase_uid,
                'name': host.display_name,
                'picture': None,
                'score': 0,
                'rank': 0,
                'is_host': True,
                'is_active': True,
            },
        },
        'state': int(GameState.LOBBY_READY),
        'full': False,
        'max_players': 20,
        'n_questions': 6,
        'question_round_settings': {
            'n_questions': 6,
            'categories': None,
            'difficulty': None,
            'search_query': None,
        },
    }


@pytest.mark.asyncio
async def test_join_committed_before_start_claim_is_included() -> None:
    """The claim reads the roster after a join that committed first."""
    client = firestore.AsyncClient(project=os.environ['GOOGLE_CLOUD_PROJECT'])
    game_ref = client.collection('games').document(f'race-{uuid.uuid4()}')
    host = User(firebase_uid='race-host', display_name='Host')
    joiner = User(firebase_uid='race-joiner', display_name='Joiner')
    await game_ref.set(_lobby_data(host))

    claim_waiting = asyncio.Event()
    allow_claim = asyncio.Event()
    claim_repo = _CoordinatedGameRepository(
        client,
        claim_waiting=claim_waiting,
        allow_claim=allow_claim,
    )
    lifecycle = GameLifecycleWriter()
    runner = TransactionRunner(client)
    start_use_case = StartGameUseCase(
        firestore_client=client,
        txn_runner=runner,
        repo=claim_repo,
        db_gateway=cast(Any, object()),
        lifecycle=lifecycle,
        questions=cast(Any, object()),
        players_answers=cast(Any, object()),
    )
    claim_id = f'claim-{uuid.uuid4()}'

    async def _claim(tx: AsyncTransaction) -> dict:
        return await start_use_case._claim_start(
            game_ref=game_ref,
            tx=tx,
            current_user=host,
            claim_id=claim_id,
        )

    claim_task = asyncio.create_task(runner.run(_claim))
    try:
        await asyncio.wait_for(claim_waiting.wait(), timeout=5)
        join_use_case = JoinGameUseCase(
            firestore_client=client,
            txn_runner=TransactionRunner(client),
            repo=GameRepository(client),
            lifecycle=lifecycle,
            players=GamePlayersWriter(),
        )
        await asyncio.wait_for(
            join_use_case.execute(game_id=game_ref.id, current_user=joiner),
            timeout=5,
        )
        allow_claim.set()
        claimed_data = await asyncio.wait_for(claim_task, timeout=10)

        assert joiner.firebase_uid in claimed_data['players']
        assert claim_repo.claim_read_attempts == 1
        persisted = (await game_ref.get()).to_dict()
        assert persisted is not None
        assert joiner.firebase_uid in persisted['players']
        assert persisted['start_claim_id'] == claim_id
    finally:
        allow_claim.set()
        if not claim_task.done():
            claim_task.cancel()
        await game_ref.delete()
        client.close()


@pytest.mark.asyncio
async def test_start_join_collision_retries_loser_and_preserves_roster() -> None:
    """A real collision retries one side without dropping the joining player."""
    client = firestore.AsyncClient(project=os.environ['GOOGLE_CLOUD_PROJECT'])
    game_ref = client.collection('games').document(f'race-{uuid.uuid4()}')
    host = User(firebase_uid='collision-host', display_name='Host')
    joiner = User(firebase_uid='collision-joiner', display_name='Joiner')
    await game_ref.set(_lobby_data(host))

    start_read = asyncio.Event()
    join_read = asyncio.Event()
    join_write_queued = asyncio.Event()
    allow_start = asyncio.Event()
    allow_join_read = asyncio.Event()
    allow_join_read.set()
    start_repo = _PostReadCoordinatedGameRepository(
        client,
        marker_field='n_questions',
        read_complete=start_read,
        allow_return=allow_start,
    )
    join_repo = _PostReadCoordinatedGameRepository(
        client,
        marker_field='full',
        read_complete=join_read,
        allow_return=allow_join_read,
    )
    lifecycle = GameLifecycleWriter()
    runner = TransactionRunner(client)
    start_use_case = StartGameUseCase(
        firestore_client=client,
        txn_runner=runner,
        repo=start_repo,
        db_gateway=cast(Any, object()),
        lifecycle=lifecycle,
        questions=cast(Any, object()),
        players_answers=cast(Any, object()),
    )
    join_use_case = JoinGameUseCase(
        firestore_client=client,
        txn_runner=TransactionRunner(client),
        repo=join_repo,
        lifecycle=lifecycle,
        players=cast(Any, _SignalingPlayersWriter(join_write_queued)),
    )
    claim_id = f'claim-{uuid.uuid4()}'

    async def _claim(tx: AsyncTransaction) -> dict:
        return await start_use_case._claim_start(
            game_ref=game_ref,
            tx=tx,
            current_user=host,
            claim_id=claim_id,
        )

    claim_task = asyncio.create_task(runner.run(_claim))
    join_task: asyncio.Task[Any] | None = None
    try:
        await asyncio.wait_for(start_read.wait(), timeout=5)
        join_task = asyncio.create_task(
            join_use_case.execute(game_id=game_ref.id, current_user=joiner),
        )
        await asyncio.wait_for(join_write_queued.wait(), timeout=5)

        # The join callback has read the old lobby and queued its write. Give its
        # commit RPC a chance to block behind the start transaction's read lock,
        # then release start so Firestore must abort and retry one contender.
        await asyncio.sleep(0.1)
        allow_start.set()
        claim_result, join_result = await asyncio.wait_for(
            asyncio.gather(claim_task, join_task, return_exceptions=True),
            timeout=30,
        )

        assert isinstance(claim_result, dict)
        persisted = (await game_ref.get()).to_dict()
        assert persisted is not None
        assert persisted['start_claim_id'] == claim_id

        if isinstance(join_result, HTTPException):
            assert join_result.status_code == 409
            assert joiner.firebase_uid not in claim_result['players']
            assert joiner.firebase_uid not in persisted['players']
            assert join_repo.read_attempts >= 2
        else:
            assert join_result.resource_id == game_ref.id
            assert joiner.firebase_uid in claim_result['players']
            assert joiner.firebase_uid in persisted['players']
            assert start_repo.read_attempts >= 2
    finally:
        allow_start.set()
        if not claim_task.done():
            claim_task.cancel()
        if join_task is not None and not join_task.done():
            join_task.cancel()
        await game_ref.delete()
        client.close()

"""Firestore-emulator regression for a join racing the start claim."""

from __future__ import annotations

import asyncio
import os
import uuid
from typing import TYPE_CHECKING, Any, cast

import pytest
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


@pytest.mark.asyncio
async def test_join_committed_before_start_claim_is_included_after_retry() -> None:
    """Firestore retries the claim after the join changes the roster."""
    client = firestore.AsyncClient(project=os.environ['GOOGLE_CLOUD_PROJECT'])
    game_ref = client.collection('games').document(f'race-{uuid.uuid4()}')
    host = User(firebase_uid='race-host', display_name='Host')
    joiner = User(firebase_uid='race-joiner', display_name='Joiner')
    await game_ref.set(
        {
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
        },
    )

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

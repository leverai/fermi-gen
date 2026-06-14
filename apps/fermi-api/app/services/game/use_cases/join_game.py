"""Use case for joining an existing game.

Moves the transactional body from the service layer into a focused use case
invoked via ``TransactionRunner``. Reads are centralized through the
``GameRepository`` and writes are delegated to managers.

Questions are fetched at game start (not on join), so joining simply adds the
player and keeps the lobby ready. There is no per-join re-fetch and therefore
no version coordination.
"""

from typing import TYPE_CHECKING, cast

from fastapi import HTTPException, status
from opentelemetry import trace

import app.logging.attributes as attrs
from app.schemas.endpoints import IdModel
from app.schemas.game import GamePlayer, GameState
from app.services.game.errors import StateConflictError
from app.services.game.repositories.game_repo import GameRepository
from app.services.game.transactions.runner import TransactionRunner

if TYPE_CHECKING:
    from fermi_db.models.user import User
    from google.cloud.firestore_v1 import (
        AsyncClient,
        AsyncDocumentReference,
        AsyncTransaction,
    )

    from app.services.game.writers.lifecycle_writer import GameLifecycleWriter
    from app.services.game.writers.players_writer import GamePlayersWriter


class JoinGameUseCase:
    """Encapsulates the transactional join-game flow."""

    def __init__(
        self,
        *,
        firestore_client: 'AsyncClient',
        txn_runner: 'TransactionRunner',
        repo: GameRepository,
        lifecycle: 'GameLifecycleWriter',
        players: 'GamePlayersWriter',
    ) -> None:
        """Initialize the use case with required collaborators."""
        self._client = firestore_client
        self._txn_runner = txn_runner
        self._repo = repo
        self._lifecycle = lifecycle
        self._players = players

    async def _perform_join(
        self,
        *,
        game_ref: 'AsyncDocumentReference',
        tx: 'AsyncTransaction',
        current_user: 'User',
    ) -> str:
        data = await self._repo.get_game_fields(
            game_ref,
            fields=[
                'state',
                'players',
                'full',
                'max_players',
            ],
            tx=tx,
        )
        if not data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail='Game not found',
            )

        if data['full']:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='Game is full',
            )

        # Set OTel attributes after successful read
        span = trace.get_current_span()
        state = GameState(int(data['state']))
        span.set_attribute(attrs.GAME_STATE, state.name)
        players = cast(dict[str, GamePlayer], data.get('players', {}))
        span.set_attribute(attrs.GAME_PLAYER_COUNT, len(players))
        max_players = int(data['max_players'])

        # Validate we're still in the lobby (keeps state at LOBBY_READY)
        try:
            self._lifecycle.join_game(
                game_ref=game_ref,
                writer=tx,
                state=state,
            )
        except StateConflictError as err:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=str(err),
            ) from err

        # Add the player
        try:
            self._players.add_player(
                game_ref=game_ref,
                writer=tx,
                players=players,
                user=current_user,
                max_players=max_players,
            )
        except StateConflictError as err:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=str(err),
            ) from err

        return game_ref.id

    async def execute(
        self,
        *,
        game_id: str,
        current_user: 'User',
    ) -> IdModel:
        """Join an existing game."""
        game_ref = self._client.collection('games').document(game_id)

        async def _tx(tx: 'AsyncTransaction') -> str:
            return await self._perform_join(
                game_ref=game_ref,
                tx=tx,
                current_user=current_user,
            )

        joined_id = cast(str, await self._txn_runner.run(_tx))
        return IdModel(resource_id=joined_id)

    async def execute_in_transaction(
        self,
        *,
        tx: 'AsyncTransaction',
        game_id: str,
        current_user: 'User',
    ) -> IdModel:
        """Join using an existing Firestore transaction provided by the caller."""
        game_ref = self._client.collection('games').document(game_id)
        joined_id = await self._perform_join(
            game_ref=game_ref,
            tx=tx,
            current_user=current_user,
        )
        return IdModel(resource_id=joined_id)

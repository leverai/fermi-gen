"""Use case for adding bots to a game.

Allows the host to add bots to a game in lobby state by specifying their IDs.
Bots are virtual players that will have their answers auto-submitted when
questions are revealed.
"""

from typing import TYPE_CHECKING, cast

from fastapi import HTTPException, status

from app.schemas.game import GamePlayer, GameState
from app.services.game.bots import BOT_IDS, BOTS
from app.services.game.errors import StateConflictError
from app.services.game.transactions.runner import TransactionRunner

if TYPE_CHECKING:
    from fastapi import Request
    from fermi_db.models.user import User
    from google.cloud.firestore_v1 import AsyncClient, AsyncTransaction

    from app.services.game.repositories.game_repo import GameRepository
    from app.services.game.writers.lifecycle_writer import GameLifecycleWriter


class AddBotsUseCase:
    """Add bots to a game that is still in lobby state."""

    def __init__(
        self,
        *,
        firestore_client: 'AsyncClient',
        txn_runner: 'TransactionRunner',
        repo: 'GameRepository',
        lifecycle: 'GameLifecycleWriter',
    ) -> None:
        """Initialize the use case with required collaborators."""
        self._client = firestore_client
        self._txn_runner = txn_runner
        self._repo = repo
        self._lifecycle = lifecycle

    async def execute(
        self,
        *,
        request: 'Request',
        game_id: str,
        current_user: 'User',
        bot_ids: list[str],
    ) -> list[str]:
        """Add bots to the game and return list of added bot IDs.

        Args:
            request: FastAPI request object for constructing absolute URLs.
            game_id: The game to add bots to.
            current_user: The user making the request (must be host).
            bot_ids: List of bot IDs to add (e.g., ['bot-gpt51', 'bot-gemini2']).

        Returns:
            List of bot IDs that were added.

        Raises:
            HTTPException: If validation fails or user is not host.

        """
        # Validate bot_ids is not empty
        if not bot_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail='bot_ids must not be empty',
            )

        # Validate no duplicates in requested bot_ids
        if len(bot_ids) != len(set(bot_ids)):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail='bot_ids must be unique (no duplicates)',
            )

        # Validate all bot_ids are valid
        invalid_ids = [bid for bid in bot_ids if bid not in BOT_IDS]
        if invalid_ids:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f'Invalid bot IDs: {invalid_ids}. Valid IDs: {sorted(BOT_IDS)}',
            )

        game_ref = self._client.collection('games').document(game_id)
        base_url = str(request.base_url).rstrip('/')

        async def _tx(tx: 'AsyncTransaction') -> None:
            data = await self._repo.get_game_fields(
                game_ref,
                fields=[
                    'host',
                    'players',
                    'state',
                    'max_players',
                    'start_claim_id',
                ],
                tx=tx,
            )
            if not data:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail='Game not found',
                )

            if data.get('host') != current_user.firebase_uid:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail='Only host can add bots',
                )

            state = GameState(int(data['state']))
            try:
                self._lifecycle.ensure_lobby_mutation_allowed(
                    state=state,
                    start_claim_id=data.get('start_claim_id'),
                )
            except StateConflictError as err:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=str(err),
                ) from err

            max_players = int(data['max_players'])
            players = cast(dict[str, GamePlayer], data['players'])
            existing_bot_ids = {pid for pid in players if pid in BOT_IDS}
            human_count = len(players) - len(existing_bot_ids)

            already_in_game = [bid for bid in bot_ids if bid in existing_bot_ids]
            if already_in_game:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f'Bots already in game: {already_in_game}',
                )

            total_after_add = human_count + len(existing_bot_ids) + len(bot_ids)
            if total_after_add > max_players:
                available_slots = max_players - human_count - len(existing_bot_ids)
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f'Adding {len(bot_ids)} bots would exceed max players. '
                    f'Only {available_slots} slot(s) available.',
                )

            for bot_id in bot_ids:
                bot = BOTS[bot_id]
                bot_player = GamePlayer(
                    player_id=bot_id,
                    name=bot['name'],
                    picture=f'{base_url}{bot["picture"]}',
                    score=0,
                    rank=0,
                    is_host=False,
                    is_active=True,
                )
                tx.update(game_ref, {f'players.{bot_id}': bot_player})

            tx.update(game_ref, {'full': total_after_add >= max_players})

        await self._txn_runner.run(_tx)

        return bot_ids

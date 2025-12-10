"""Use case for adding bots to a game.

Allows the host to add up to 3 bots to a game in lobby state. Bots are
virtual players that will have their answers auto-submitted when questions
are revealed.
"""

from typing import TYPE_CHECKING, cast

from fastapi import HTTPException, status

from app.schemas.game import GamePlayer, GameState
from app.services.game.bots import BOT_ORDER, BOTS
from app.services.game.writers.players_writer import MAX_PLAYERS

if TYPE_CHECKING:
    from fastapi import Request
    from fermi_db.models.user import User
    from google.cloud.firestore_v1 import AsyncClient

    from app.services.game.repositories.game_repo import GameRepository


class AddBotsUseCase:
    """Add bots to a game that is still in lobby state."""

    def __init__(
        self,
        *,
        firestore_client: 'AsyncClient',
        repo: 'GameRepository',
    ) -> None:
        """Initialize the use case with required collaborators."""
        self._client = firestore_client
        self._repo = repo

    async def execute(
        self,
        *,
        request: 'Request',
        game_id: str,
        current_user: 'User',
        bot_count: int,
    ) -> list[str]:
        """Add bots to the game and return list of added bot IDs.

        Args:
            request: FastAPI request object for constructing absolute URLs.
            game_id: The game to add bots to.
            current_user: The user making the request (must be host).
            bot_count: Number of bots to add (1-3).

        Returns:
            List of bot IDs that were added.

        Raises:
            HTTPException: If validation fails or user is not host.

        """
        if bot_count < 1 or bot_count > 3:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail='bot_count must be 1, 2, or 3',
            )

        game_ref = self._client.collection('games').document(game_id)

        # Read game data
        data = await self._repo.get_game_fields(
            game_ref,
            fields=['host', 'players', 'state'],
        )
        if not data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail='Game not found',
            )

        # Validate host
        if data.get('host') != current_user.firebase_uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail='Only host can add bots',
            )

        # Validate state
        state = GameState(int(data['state']))
        if state not in (GameState.LOBBY_NOT_READY, GameState.LOBBY_READY):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='Can only add bots in lobby state',
            )

        # Validate player count
        players = cast(dict[str, GamePlayer], data['players'])
        existing_bot_ids = [pid for pid in players if pid in BOTS]
        human_count = len(players) - len(existing_bot_ids)

        # Remove existing bots from available pool
        available_bots = [bid for bid in BOT_ORDER if bid not in existing_bot_ids]
        bots_to_add = available_bots[:bot_count]

        if len(bots_to_add) < bot_count:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f'Only {len(bots_to_add)} more bots can be added',
            )

        if human_count + len(existing_bot_ids) + len(bots_to_add) > MAX_PLAYERS:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail='Adding bots would exceed max player limit',
            )

        # Construct base URL for absolute avatar URLs
        base_url = str(request.base_url).rstrip('/')

        # Add bots to players map
        batch = self._client.batch()
        for bot_id in bots_to_add:
            bot = BOTS[bot_id]
            # Convert relative picture URL to absolute URL
            picture_url = f'{base_url}{bot["picture"]}'
            bot_player = GamePlayer(
                player_id=bot_id,
                name=bot['name'],
                picture=picture_url,
                score=0,
                rank=0,
                is_host=False,
                is_active=True,
            )
            batch.update(game_ref, {f'players.{bot_id}': bot_player})

        # Update full flag if needed
        total_players = human_count + len(existing_bot_ids) + len(bots_to_add)
        batch.update(game_ref, {'full': total_players >= MAX_PLAYERS})

        await batch.commit()

        return bots_to_add

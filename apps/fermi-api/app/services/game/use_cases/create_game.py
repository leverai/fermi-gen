"""Use case for creating a party-game lobby."""

from typing import TYPE_CHECKING

from fastapi import HTTPException, status

from app.core.config import settings
from app.schemas.endpoints import GameCreateRequest, IdModel
from app.services.game.errors import ValidationError
from app.services.game.writers.players_writer import get_max_players

if TYPE_CHECKING:
    from fastapi import Request
    from fermi_db.models.user import User
    from fermi_db.repositories.party_hosting_repository import PartyHostingRepository
    from google.cloud.firestore_v1 import AsyncClient

    from app.services.game.writers.lifecycle_writer import GameLifecycleWriter
    from app.services.game.writers.players_writer import GamePlayersWriter


class CreateGameUseCase:
    """Validate and persist a new ready lobby."""

    def __init__(
        self,
        *,
        firestore_client: 'AsyncClient',
        hosting_repo: 'PartyHostingRepository',
        lifecycle: 'GameLifecycleWriter',
        players: 'GamePlayersWriter',
        free_hosting_limit: int,
    ) -> None:
        """Store collaborators for the create flow."""
        self._client = firestore_client
        self._hosting_repo = hosting_repo
        self._lifecycle = lifecycle
        self._players = players
        self._free_hosting_limit = free_hosting_limit

    async def execute(
        self,
        *,
        request: 'Request',
        payload: GameCreateRequest,
        current_user: 'User',
        is_pro: bool,
    ) -> IdModel:
        """Create a lobby after enforcing limits and feature access."""
        assert current_user.id is not None
        allowed = (
            True
            if is_pro
            else await self._hosting_repo.get_hostings_remaining(
                user_id=current_user.id,
                limit=self._free_hosting_limit,
            )
        )
        if not allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail='Weekly party hosting limit reached',
            )

        round_settings = payload.question_round_settings
        if round_settings.search_query:
            if not settings.smart_search_enabled:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail='Smart search is not available',
                )
            round_settings = round_settings.model_copy(update={'categories': None})

        batch = self._client.batch()
        game_ref = await self._lifecycle.create_game(
            games_ref=self._client.collection('games'),
            writer=batch,
        )

        try:
            self._players.set_players(
                game_ref=game_ref,
                writer=batch,
                host_id=current_user.firebase_uid,
                users=[current_user],
                max_players=get_max_players(is_pro=is_pro),
            )
        except ValidationError as err:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=str(err),
            ) from err

        if settings.invite_url_base:
            join_url = f'{settings.invite_url_base}/invite?mode=party&id={game_ref.id}'
        else:
            base_url = str(request.base_url).rstrip('/')
            join_url = f'{base_url}/api/v1/game/invite/{game_ref.id}'

        batch.update(
            game_ref,
            {
                'join_url': join_url,
                'n_questions': round_settings.n_questions,
                'question_round_settings': round_settings.model_dump(mode='json'),
            },
        )
        self._lifecycle.set_ready(game_ref=game_ref, writer=batch)
        await batch.commit()

        return IdModel(resource_id=game_ref.id)

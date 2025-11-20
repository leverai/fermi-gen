"""Use case for ending a game.

Moves the transactional end-game mutation from the service layer into a
focused use case invoked via ``TransactionRunner``. Reads are centralized
through the ``GameRepository`` and writes are delegated to managers. The use
case returns the minimal information needed by callers to coordinate
post-commit behavior.
"""

from typing import TYPE_CHECKING, TypedDict, cast

from fastapi import HTTPException, status

from app.schemas.game import GameState
from app.services.game.errors import StateConflictError
from app.services.game.repositories.game_repo import GameRepository
from app.services.game.transactions.runner import TransactionRunner

if TYPE_CHECKING:
    from fermi_db.models.user import User
    from google.cloud.firestore_v1 import AsyncClient, AsyncTransaction

    from app.services.game.writers.lifecycle_writer import GameLifecycleWriter


class EndGameResult(TypedDict):
    """Result of an end-game attempt."""

    game_id: str
    started: bool


class EndGameUseCase:
    """Encapsulates the transactional end-game flow."""

    def __init__(
        self,
        *,
        firestore_client: 'AsyncClient',
        txn_runner: 'TransactionRunner',
        repo: GameRepository,
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
        game_id: str,
        current_user: 'User | None',
        force: bool,
    ) -> EndGameResult:
        """End the game, returning whether it had started."""
        game_ref = self._client.collection('games').document(game_id)

        async def _tx(tx: 'AsyncTransaction') -> EndGameResult:
            data = await self._repo.get_game_fields(
                game_ref,
                fields=['state', 'host'],
                tx=tx,
            )
            if not data:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail='Game not found',
                )

            if not force:
                if current_user is None or data['host'] != current_user.firebase_uid:
                    raise HTTPException(
                        status_code=status.HTTP_403_FORBIDDEN,
                        detail='Only host can end the game',
                    )

            state = GameState(int(data['state']))
            try:
                started = self._lifecycle.end_game(
                    game_ref=game_ref,
                    writer=tx,
                    current_state=state,
                )
            except StateConflictError as err:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=str(err),
                ) from err

            return EndGameResult(game_id=game_id, started=started)

        return cast(EndGameResult, await self._txn_runner.run(_tx))

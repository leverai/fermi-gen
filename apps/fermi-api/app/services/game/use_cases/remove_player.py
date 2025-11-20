"""Use case for removing a player from a game.

Encapsulates the transactional read→validate→remove flow from the service
layer. Reads are provided by ``GameRepository`` and writes are delegated to
managers. The use case returns a minimal flag to let the caller trigger
post-commit actions (e.g., ending the game).
"""

from typing import TYPE_CHECKING, TypedDict, cast

from fastapi import HTTPException, status

from app.schemas.game import AnswersProgress, GamePlayer, GameState
from app.services.game.errors import NotFoundError, StateConflictError
from app.services.game.repositories.game_repo import GameRepository
from app.services.game.transactions.runner import TransactionRunner

if TYPE_CHECKING:
    from fermi_db.models.user import User
    from google.cloud.firestore_v1 import AsyncClient, AsyncTransaction

    from app.services.game.writers.lifecycle_writer import GameLifecycleWriter
    from app.services.game.writers.players_answers_writer import (
        GamePlayersAnswersWriter,
    )
    from app.services.game.writers.players_writer import GamePlayersWriter


class RemovePlayerResult(TypedDict):
    """Result of removing a player."""

    game_id: str
    should_end_game: bool


class RemovePlayerUseCase:
    """Encapsulates transactional player removal and optional finish logic."""

    def __init__(
        self,
        *,
        firestore_client: 'AsyncClient',
        txn_runner: 'TransactionRunner',
        repo: GameRepository,
        lifecycle: 'GameLifecycleWriter',
        players: 'GamePlayersWriter',
        players_answers: 'GamePlayersAnswersWriter',
    ) -> None:
        """Initialize the use case with required collaborators."""
        self._client = firestore_client
        self._txn_runner = txn_runner
        self._repo = repo
        self._lifecycle = lifecycle
        self._players = players
        self._players_answers = players_answers

    async def execute(
        self,
        *,
        game_id: str,
        actor_user: 'User',
        remove_player_id: str,
    ) -> RemovePlayerResult:
        """Remove ``remove_player_id`` from ``game_id``.

        Returns a flag to indicate whether the caller should end the game
        after the transaction commits.
        """
        game_ref = self._client.collection('games').document(game_id)

        async def _tx(tx: 'AsyncTransaction') -> RemovePlayerResult:
            data = await self._repo.get_game_fields(
                game_ref,
                fields=['state', 'players', 'progress', 'host', 'question_uid'],
                tx=tx,
            )
            if not data:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail='Game not found',
                )

            # Only host may remove other players; anyone may remove themselves
            is_host = actor_user.firebase_uid == data['host']
            if not is_host and actor_user.firebase_uid != remove_player_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail='Only host can remove other players',
                )

            players = cast(dict[str, GamePlayer], data['players'])
            state = GameState(int(data['state']))

            # Remove from players (and possibly update host/full)
            try:
                active_player_ids = self._players.remove_player(
                    game_ref=game_ref,
                    writer=tx,
                    players=players,
                    remove_id=remove_player_id,
                    state=state,
                    is_host=is_host,
                )
            except NotFoundError as err:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=str(err),
                ) from err
            # No other domain errors expected from players.remove_player

            # If no active players remain, signal to end the game post-commit
            if not active_player_ids:
                return RemovePlayerResult(game_id=game_id, should_end_game=True)

            # If there is an active question, update progress and potentially
            # finish and reveal results when the last needed answer is removed
            next_state = state
            if state in (GameState.QUESTION_N, GameState.QUESTION_LAST):
                try:
                    all_answered = self._players_answers.remove_player(
                        game_ref=game_ref,
                        writer=tx,
                        remove_id=remove_player_id,
                        progress=cast(AnswersProgress, data.get('progress', {})),
                    )
                except NotFoundError as err:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail=str(err),
                    ) from err
                # No other domain errors expected from players_answers.remove_player
                if all_answered:
                    try:
                        next_state = self._lifecycle.finish_question(
                            game_ref=game_ref,
                            writer=tx,
                            state=state,
                        )
                    except StateConflictError as err:
                        raise HTTPException(
                            status_code=status.HTTP_409_CONFLICT,
                            detail=str(err),
                        ) from err
                    # No other domain errors expected from lifecycle.finish_question
                    self._players_answers.reveal_players_results(
                        game_ref=game_ref,
                        writer=tx,
                        question_uid=cast(str, data['question_uid']),
                    )

            return RemovePlayerResult(
                game_id=game_id,
                should_end_game=(next_state == GameState.QUESTION_LAST_FINISHED),
            )

        return cast(RemovePlayerResult, await self._txn_runner.run(_tx))

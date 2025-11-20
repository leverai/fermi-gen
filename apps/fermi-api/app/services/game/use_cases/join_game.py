"""Use case for joining an existing game.

Moves the transactional body from the service layer into a focused use case
invoked via ``TransactionRunner``. Reads are centralized through the
``GameRepository`` and writes are delegated to managers. The use case returns
the minimal information needed by the caller to schedule post-commit tasks.
"""

import uuid
from typing import TYPE_CHECKING, TypedDict, cast

from fastapi import HTTPException, status
from fermi_db.schemas import QuestionDifficulty

from app.schemas.endpoints import QuestionRoundSettings, RequestCategory
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
    from app.services.game.writers.questions_writer import GameQuestionsWriter


class JoinGameResult(TypedDict):
    """Result of a successful join operation."""

    game_id: str
    version_uid: str
    question_round_settings: QuestionRoundSettings
    players_uids: list[str]


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
        questions: 'GameQuestionsWriter',
    ) -> None:
        """Initialize the use case with required collaborators."""
        self._client = firestore_client
        self._txn_runner = txn_runner
        self._repo = repo
        self._lifecycle = lifecycle
        self._players = players
        self._questions = questions

    async def _perform_join(
        self,
        *,
        game_ref: 'AsyncDocumentReference',
        tx: 'AsyncTransaction',
        current_user: 'User',
    ) -> JoinGameResult:
        data = await self._repo.get_game_fields(
            game_ref,
            fields=[
                'state',
                'players',
                'full',
                'question_uids',
                'n_questions',
                'category',
                'difficulty',
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

        # Update lifecycle state back to not-ready (someone joined)
        state = GameState(int(data['state']))
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
            players_uids = self._players.add_player(
                game_ref=game_ref,
                writer=tx,
                players=cast(dict[str, GamePlayer], data['players']),
                user=current_user,
            )
        except StateConflictError as err:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=str(err),
            ) from err

        # Clear existing questions so they can be re-fetched for the new roster
        question_uids = cast(list[str] | None, data.get('question_uids'))
        if question_uids:
            self._questions.clear_questions(
                game_ref=game_ref,
                writer=tx,
                question_uids=question_uids,
            )

        request_cat = (
            RequestCategory(str(data['category']))
            if data.get('category') is not None
            else None
        )
        qrs = QuestionRoundSettings(
            n_questions=int(data['n_questions']),
            category=request_cat,
            difficulty=(
                QuestionDifficulty(data['difficulty'])
                if data.get('difficulty') is not None
                else None
            ),
        )

        version_uid = str(uuid.uuid4())
        tx.update(game_ref, {'version_uid': version_uid})

        return JoinGameResult(
            game_id=game_ref.id,
            version_uid=version_uid,
            question_round_settings=qrs,
            players_uids=players_uids,
        )

    async def execute(
        self,
        *,
        game_id: str,
        current_user: 'User',
    ) -> JoinGameResult:
        """Join an existing game, returning data for post-commit tasks."""
        game_ref = self._client.collection('games').document(game_id)

        async def _tx(tx: 'AsyncTransaction') -> JoinGameResult:
            return await self._perform_join(
                game_ref=game_ref,
                tx=tx,
                current_user=current_user,
            )

        return cast(JoinGameResult, await self._txn_runner.run(_tx))

    async def execute_in_transaction(
        self,
        *,
        tx: 'AsyncTransaction',
        game_id: str,
        current_user: 'User',
    ) -> JoinGameResult:
        """Join using an existing Firestore transaction provided by the caller."""
        game_ref = self._client.collection('games').document(game_id)
        return await self._perform_join(
            game_ref=game_ref,
            tx=tx,
            current_user=current_user,
        )

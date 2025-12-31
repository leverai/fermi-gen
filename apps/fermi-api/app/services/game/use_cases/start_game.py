"""Use case for starting a game and revealing the first question.

Encapsulates orchestration that was previously in ``service.py``. Reads the
minimal fields via the repository, enforces host-only permissions, performs
document updates via managers in a single batch, and commits.
"""

from typing import TYPE_CHECKING, cast

from fastapi import HTTPException, status

from app.schemas.endpoints import IdModel
from app.schemas.game import GamePlayer, GameState
from app.services.game.errors import StateConflictError
from app.services.game.repositories.game_repo import GameRepository

if TYPE_CHECKING:
    from fermi_db.models.user import User
    from google.cloud.firestore_v1.async_client import AsyncClient

    from app.services.game.writers.lifecycle_writer import GameLifecycleWriter
    from app.services.game.writers.players_answers_writer import (
        GamePlayersAnswersWriter,
    )
    from app.services.game.writers.questions_writer import GameQuestionsWriter


class StartGameUseCase:
    """Start the game by revealing the first question and initializing progress."""

    def __init__(
        self,
        *,
        firestore_client: 'AsyncClient',
        repo: GameRepository,
        lifecycle: 'GameLifecycleWriter',
        questions: 'GameQuestionsWriter',
        players_answers: 'GamePlayersAnswersWriter',
    ) -> None:
        """Initialize the use case with required collaborators."""
        self._client = firestore_client
        self._repo = repo
        self._lifecycle = lifecycle
        self._questions = questions
        self._players_answers = players_answers

    async def execute(
        self,
        *,
        game_id: str,
        current_user: 'User',
    ) -> IdModel:
        """Start the game and reveal the first question for `game_id`."""
        game_ref = self._client.collection('games').document(game_id)

        # Read minimal fields
        data = await self._repo.get_game_fields(
            game_ref,
            fields=[
                'host',
                'players',
                'question_uids',
                'n_questions',
                'state',
            ],
        )
        if not data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail='Game not found',
            )

        # Enforce host-only access
        if data.get('host') != current_user.firebase_uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail='Only host can start the game',
            )

        # Validate questions exist
        question_uids = cast(list[str], data.get('question_uids') or [])
        if not question_uids:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail='Game has no questions',
            )

        # Perform writes in a batch
        batch = self._client.batch()

        # Reveal first question
        first_q_uid = question_uids[0]
        self._questions.reveal_question(
            game_ref=game_ref,
            writer=batch,
            question_uid=first_q_uid,
            question_order=1,
        )

        # Init progress for all players
        players = cast(dict[str, GamePlayer], data['players'])
        self._players_answers.init_progress(
            game_ref=game_ref,
            writer=batch,
            players_ids=players,
        )

        # Start lifecycle (sets started_at and state)
        state = GameState(int(data['state']))
        n_questions = int(data['n_questions'])
        try:
            self._lifecycle.start_game(
                game_ref=game_ref,
                writer=batch,
                state=state,
                n_questions=n_questions,
            )
        except StateConflictError as err:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=str(err),
            ) from err

        await batch.commit()
        return IdModel(resource_id=game_id)

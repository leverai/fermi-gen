"""Use case for revealing the next question in a game.

This module encapsulates the orchestration previously implemented directly in
``service.py``. It performs the minimal reads via the repository and delegates
writes to managers, keeping Firestore semantics clear and centralized.
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


class NextQuestionUseCase:
    """Reveal the next question and initialize answer progress.

    Responsibilities:
    - Read minimal game fields via ``GameRepository``
    - Enforce host-only access
    - Delegate state transition and document updates to managers using a batch
    - Commit the batch and return the ``GameIdModel``
    """

    def __init__(
        self,
        *,
        firestore_client: 'AsyncClient',
        repo: GameRepository,
        lifecycle: 'GameLifecycleWriter',
        questions: 'GameQuestionsWriter',
        players_answers: 'GamePlayersAnswersWriter',
    ) -> None:
        """Initialize the use case."""
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
        """Execute the transition to the next question.

        Raises 404/403/409 errors for missing game, permissions, or state
        conflicts, mapping closely to prior behavior.
        """
        game_ref = self._client.collection('games').document(game_id)

        # 1) Read minimal fields needed to validate and proceed
        data = await self._repo.get_game_fields(
            game_ref,
            fields=[
                'state',
                'question_uids',
                'question_order',
                'players',
                'host',
            ],
        )
        if not data:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail='Game not found',
            )

        # 2) Enforce host-only access
        if data.get('host') != current_user.firebase_uid:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail='Only host can move to the next question',
            )

        # 3) Perform writes in a single batch
        batch = self._client.batch()
        state = GameState(int(data['state']))
        question_uids = cast(list[str], data['question_uids'])
        try:
            next_question_order = self._lifecycle.next_question(
                game_ref=game_ref,
                writer=batch,
                state=state,
                question_order=int(data['question_order']),
                n_questions=len(question_uids),
            )
        except StateConflictError as err:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=str(err),
            ) from err

        next_question_uid = question_uids[next_question_order - 1]
        self._questions.reveal_question(
            game_ref=game_ref,
            writer=batch,
            question_uid=next_question_uid,
            question_order=next_question_order,
        )

        active_player_ids = [
            pid
            for pid, pinfo in cast(
                dict[str, GamePlayer],
                data['players'],
            ).items()
            if pinfo['is_active']
        ]
        self._players_answers.init_progress(
            game_ref=game_ref,
            writer=batch,
            players_ids=active_player_ids,
        )

        await batch.commit()
        return IdModel(resource_id=game_id)

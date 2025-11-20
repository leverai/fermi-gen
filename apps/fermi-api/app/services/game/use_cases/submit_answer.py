"""Use case for submitting an answer to the active question.

Moves the transactional read→score→write logic from the service layer into a
focused use case invoked via ``TransactionRunner``. Reads are centralized
through the ``GameRepository`` and writes are delegated to managers. The use
case returns a minimal flag to allow callers to schedule post-commit actions.
"""

from typing import TYPE_CHECKING, TypedDict, cast

from fastapi import HTTPException, status

from app.schemas.game import AnswersProgress, GamePlayer, GameState
from app.services.game.errors import NotFoundError, StateConflictError
from app.services.game.repositories.game_repo import GameRepository

if TYPE_CHECKING:
    from fermi_db.schemas import AnswerBare
    from google.cloud.firestore_v1 import (
        AsyncClient,
        AsyncTransaction,
    )

    from app.services.game.transactions.runner import TransactionRunner
    from app.services.game.writers.lifecycle_writer import GameLifecycleWriter
    from app.services.game.writers.players_answers_writer import (
        GamePlayersAnswersWriter,
    )
    from app.services.game.writers.players_writer import GamePlayersWriter


class SubmitAnswerResult(TypedDict):
    """Result from submitting an answer."""

    game_id: str
    questions_finished: bool


class SubmitAnswerUseCase:
    """Encapsulates transactional answer submission and reveal/finish logic."""

    def __init__(
        self,
        *,
        firestore_client: 'AsyncClient',
        txn_runner: 'TransactionRunner',
        repo: GameRepository,
        lifecycle: 'GameLifecycleWriter',
        players_answers: 'GamePlayersAnswersWriter',
        players: 'GamePlayersWriter',
    ) -> None:
        """Initialize the use case with required collaborators."""
        self._client = firestore_client
        self._txn_runner = txn_runner
        self._repo = repo
        self._lifecycle = lifecycle
        self._players_answers = players_answers
        self._players = players

    async def execute(
        self,
        *,
        game_id: str,
        player_id: str,
        answer: 'AnswerBare',
    ) -> SubmitAnswerResult:
        """Submit a player's answer for the active question in ``game_id``."""
        game_ref = self._client.collection('games').document(game_id)

        async def _tx(tx: 'AsyncTransaction') -> SubmitAnswerResult:
            # Read all data BEFORE any writes (Firestore transaction requirement)
            data = await self._repo.get_game_fields(
                game_ref,
                fields=['state', 'question_uid', 'progress', 'players'],
                tx=tx,
            )
            if not data:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail='Game not found',
                )

            question_uid = cast(str, data['question_uid'])
            correct_answer_doc = await self._repo.get_correct_answer(
                game_ref=game_ref,
                question_uid=question_uid,
                tx=tx,
            )

            # Read existing players_results to get previously submitted scores
            players_results_doc = await self._repo.get_players_results_doc(
                game_ref=game_ref,
                question_uid=question_uid,
                tx=tx,
            )

            # Now perform writes
            try:
                result = self._players_answers.submit_answer(
                    game_ref=game_ref,
                    writer=tx,
                    player_id=player_id,
                    question_uid=question_uid,
                    answer=answer,
                    correct_answer_doc=correct_answer_doc,
                    progress=cast(AnswersProgress, data['progress']),
                )
                all_answered, current_player_score = result
            except NotFoundError as err:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=str(err),
                ) from err
            except StateConflictError as err:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=str(err),
                ) from err

            state = GameState(int(data['state']))
            next_state = state
            if all_answered:
                # Combine previously submitted scores with current player's score
                question_scores: dict[str, float] = {
                    pid: result['score']['number']
                    for pid, result in players_results_doc['players_results'].items()
                }
                question_scores[player_id] = current_player_score

                # Update cumulative scores and ranks
                self._players.update_scores_and_ranks(
                    game_ref=game_ref,
                    writer=tx,
                    players=cast(dict[str, GamePlayer], data['players']),
                    question_scores=question_scores,
                )

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

                try:
                    self._players_answers.reveal_players_results(
                        game_ref=game_ref,
                        writer=tx,
                        question_uid=question_uid,
                    )
                except NotFoundError as err:
                    raise HTTPException(
                        status_code=status.HTTP_404_NOT_FOUND,
                        detail=str(err),
                    ) from err

            return SubmitAnswerResult(
                game_id=game_id,
                questions_finished=(next_state == GameState.QUESTION_LAST_FINISHED),
            )

        return cast(SubmitAnswerResult, await self._txn_runner.run(_tx))

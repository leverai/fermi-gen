"""Write-only mutations for players' answers and progress.

This module handles scoring, progress tracking, and answer-related Firestore
writes. It does not perform reads and raises domain-specific exceptions instead
of HTTP-aware ones.
"""

from collections.abc import Iterable
from typing import TYPE_CHECKING, cast

from fermi_db.schemas import AnswerBare
from google.cloud import firestore

from app.schemas.game import (
    AnswerDoc,
    AnswersProgress,
    PlayerResult,
    PlayersResultsDoc,
    Score,
    ScoreQuantiles,
)
from app.services.game.errors import NotFoundError, StateConflictError
from app.services.scoring import ScoringService
from app.services.units import (
    convert_answer_to_user_unit,
)

if TYPE_CHECKING:
    from google.cloud.firestore_v1 import (
        AsyncCollectionReference,
        AsyncDocumentReference,
    )

    from app.services.game.utils import Writeable


class GamePlayersAnswersWriter:
    """Writer for game players answers operations."""

    def __init__(self) -> None:
        """Initialize the writer."""
        self._scoring_service = ScoringService()

    def init_players_results_docs(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        question_uids: Iterable[str],
    ) -> None:
        """Init players results document for each question."""
        players_results_ref = cast(
            'AsyncCollectionReference',
            game_ref.collection('players_results'),
        )
        for question_uid in question_uids:
            players_results_doc = PlayersResultsDoc(
                question_uid=question_uid,
                players_results={},
                revealed=False,
            )
            writer.set(
                players_results_ref.document(question_uid),
                cast(dict, players_results_doc),
            )

    def init_progress(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        players_ids: Iterable[str] | dict,
    ) -> None:
        """Init players answers progress."""
        # Accept either an iterable of IDs or a dict mapping IDs
        if isinstance(players_ids, dict):
            ids = list(players_ids.keys())
        else:
            ids = list(players_ids)

        writer.update(
            game_ref,
            {
                'progress': {
                    'answered': dict.fromkeys(ids, False),
                    'all_answered': False,
                },
            },
        )

    def submit_answer(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        player_id: str,
        question_uid: str,
        answer: 'AnswerBare',
        correct_answer_doc: 'AnswerDoc',
        progress: 'AnswersProgress',
    ) -> tuple[bool, float, 'PlayerResult']:
        """Submit and score a player's answer for the current question.

        Returns:
            A tuple of (all_answered, score_number, player_result) where:
            - all_answered indicates if all players have now answered
            - score_number is the score earned by this player for this question
            - player_result is the PlayerResult object for this player

        Raises:
            NotFoundError: If the player is not tracked in progress.
            StateConflictError: If the player already answered.

        """
        if player_id not in progress['answered']:
            raise NotFoundError('Player not found in progress')
        if progress['answered'][player_id]:
            raise StateConflictError('Player already answered')

        correct_answer = AnswerBare(
            number=correct_answer_doc['number'],
            unit=correct_answer_doc['unit'],
        )
        score_number = self._scoring_service.calculate_score(
            player_answer=answer,
            correct_answer=correct_answer,
        )
        quantile = self._scoring_service.get_score_quantile(
            score=score_number,
            quantiles=cast(ScoreQuantiles, correct_answer_doc['quantiles']),
        )
        # Get correct answer in user's base unit if not dimensionless
        if answer['unit']:
            # user_locale = get_unit_locale(answer['unit'])
            # correct_answer_user_base_unit = convert_answer_to_locale_base_unit(
            #     correct_answer,
            #     locale=user_locale,
            # )
            correct_answer_user_unit = convert_answer_to_user_unit(
                player_unit_id=answer['unit'],
                correct_answer=correct_answer,
            )
        else:
            correct_answer_user_unit = correct_answer

        player_result = PlayerResult(
            answer=answer,
            correct_answer=correct_answer_user_unit,
            score=Score(
                number=score_number,
                quantile=quantile,
            ),
        )

        players_results_ref = cast(
            'AsyncCollectionReference',
            game_ref.collection('players_results'),
        )
        writer.update(
            players_results_ref.document(question_uid),
            {
                f'players_results.{player_id}': player_result,
            },
        )

        all_answered = all(
            val for pid, val in progress['answered'].items() if pid != player_id
        )

        writer.update(
            game_ref,
            {
                f'progress.answered.{player_id}': True,
                'progress.all_answered': all_answered,
            },
        )

        return all_answered, score_number, player_result

    def reveal_players_results(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        question_uid: str,
        players_results_doc: 'PlayersResultsDoc',
        current_player_id: str | None = None,
        current_player_result: 'PlayerResult | None' = None,
    ) -> None:
        """Reveal players results for a question.

        Computes converted_answers for each player, showing all other players'
        answers converted to that player's unit. This allows each player to
        compare answers in their preferred unit system.

        Note: Due to Firestore transaction semantics, the current player's result
        may not be visible in the read-before-write snapshot. When provided as
        parameters, we merge them in-memory before computing conversions.

        Args:
            game_ref: Reference to the game document.
            writer: Writeable object (transaction or batch) for Firestore writes.
            question_uid: UID of the question being revealed.
            players_results_doc: The current players_results document containing
                previously submitted players' answers and scores.
            current_player_id: Optional ID of the player who just submitted.
                Only needed when revealing after a new answer submission.
            current_player_result: Optional PlayerResult for the current player.
                Only needed when revealing after a new answer submission.

        """
        players_results_ref = cast(
            'AsyncCollectionReference',
            game_ref.collection('players_results'),
        )

        # Start with existing players from the snapshot
        players_results = dict(players_results_doc['players_results'])

        # Merge current player's result if provided (not visible in read-before-
        # write snapshot during normal answer submission flow)
        if current_player_id is not None and current_player_result is not None:
            players_results[current_player_id] = current_player_result

        # Compute converted_answers for each player
        updates: dict[str, dict[str, AnswerBare]] = {}

        for player_id, player_result in players_results.items():
            player_unit = player_result['answer']['unit']
            converted_answers: dict[str, AnswerBare] = {}

            # Convert all other players' answers to this player's unit
            for other_player_id, other_result in players_results.items():
                if other_player_id == player_id:
                    # Skip self
                    continue

                other_answer = other_result['answer']

                # If dimensionless (no unit), no conversion needed
                if player_unit is None:
                    converted_answers[other_player_id] = other_answer
                else:
                    # Convert other player's answer to this player's unit
                    converted_answers[other_player_id] = convert_answer_to_user_unit(
                        player_unit_id=player_unit,
                        correct_answer=other_answer,
                    )

            updates[player_id] = converted_answers

        # Write all updates in a single Firestore update
        update_dict = {
            f'players_results.{player_id}.converted_answers': converted_answers
            for player_id, converted_answers in updates.items()
        }
        update_dict['revealed'] = True

        writer.update(players_results_ref.document(question_uid), update_dict)

    def remove_player(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        remove_id: str,
        progress: 'AnswersProgress',
    ) -> bool:
        """Remove a player from progress and update all_answered when needed.

        Raises:
            NotFoundError: If the player is not tracked in progress.

        """
        if remove_id not in progress['answered']:
            raise NotFoundError('Player not found in progress')

        if progress['answered'][remove_id]:
            return progress['all_answered']

        all_answered = all(
            val for pid, val in progress['answered'].items() if pid != remove_id
        )

        writer.update(
            game_ref,
            {
                f'progress.answered.{remove_id}': firestore.DELETE_FIELD,
                'progress.all_answered': all_answered,
            },
        )

        return all_answered

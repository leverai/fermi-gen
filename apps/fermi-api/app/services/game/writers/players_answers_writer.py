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
    ) -> tuple[bool, float]:
        """Submit and score a player's answer for the current question.

        Returns:
            A tuple of (all_answered, score_number) where all_answered indicates
            if all players have now answered, and score_number is the score earned
            by this player for this question.

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

        return all_answered, score_number

    def reveal_players_results(
        self,
        game_ref: 'AsyncDocumentReference',
        writer: 'Writeable',
        question_uid: str,
    ) -> None:
        """Reveal players results for a question."""
        players_results_ref = cast(
            'AsyncCollectionReference',
            game_ref.collection('players_results'),
        )
        writer.update(players_results_ref.document(question_uid), {'revealed': True})

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

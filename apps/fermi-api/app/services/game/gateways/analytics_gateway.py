"""Gateway to the analytics database.

This module serves as an adapter to the Postgres-based analytics and history
database. It fetches raw data from the database, converts it to domain-specific
documents, and archives game results. It is designed to be a pure adapter and
has no knowledge of Firestore or HTTP semantics.
"""

import asyncio
import uuid
from typing import TYPE_CHECKING, cast

from fermi_core.units import get_unit_family
from fermi_db.models import AnswerEvent
from fermi_db.models.game import VoteVerdict
from fermi_db.schemas import QuestionCategory

from app.schemas.endpoints import PlayerStats
from app.schemas.game import (
    AnswerDoc,
    PlayersResultsDoc,
    QuestionDoc,
    ScoreQuantiles,
)

if TYPE_CHECKING:
    from fermi_db import DatabaseClient

    from app.schemas.endpoints import QuestionRoundSettings, QuestionSettings


class GameAnalyticsGateway:
    """Gateway for game-related analytics and history database operations.

    This class is a pure adapter to the Postgres DAL. It does not know about
    HTTP or Firestore.
    """

    def __init__(self, db_client: 'DatabaseClient') -> None:
        """Initialize the game analytics gateway."""
        self._db_client = db_client

    async def get_questions_and_answers_docs(
        self,
        user_ids: list[str],
        question_round_settings: 'QuestionRoundSettings',
    ) -> tuple[list[QuestionDoc], list[AnswerDoc]]:
        """Get questions and their answers from the database."""
        request_category = cast(
            QuestionCategory | None,
            question_round_settings.category,
        )
        # 1. Fetch questions (with correct answers)
        questions = await self._db_client.users_history.get_unseen_random_questions(
            count=question_round_settings.n_questions,
            for_user_ids=user_ids,
            category=request_category,
            difficulty=question_round_settings.difficulty,
        )

        # 2. Get quantiles
        quantiles_tasks = [
            self._db_client.answers.get_question_quantiles(question.uid)
            for question in questions
        ]
        quantiles = await asyncio.gather(*quantiles_tasks)

        # 3. Create docs
        questions_docs: list[QuestionDoc] = []
        answers_docs: list[AnswerDoc] = []
        for idx, (question, q_quantiles) in enumerate(
            zip(questions, quantiles, strict=True),
            start=1,
        ):
            units = get_unit_family(question.unit) if question.unit else None
            # Aggregate upvotes from votes table
            upvotes = await self._db_client.question_votes.get_upvotes(
                question.uid,
            )
            # Aggregate players votes from votes table
            players_votes = (
                await self._db_client.question_votes.get_players_vote_verdicts(
                    question.uid,
                    user_ids,
                )
            )
            questions_docs.append(
                QuestionDoc(
                    question_uid=str(question.uid),
                    text=question.text,
                    category=question.category,
                    difficulty=question.difficulty,
                    year=question.updated_at.year,
                    order=idx,
                    units=units,
                    upvotes=upvotes,
                    revealed=False,
                    players_votes=players_votes,
                ),
            )
            answers_docs.append(
                AnswerDoc(
                    number=question.number,
                    unit=question.unit,
                    paragraph=question.snippet,
                    quantiles=cast(
                        ScoreQuantiles,
                        q_quantiles.model_dump(exclude={'question_uid'}),
                    ),
                    revealed=False,
                ),
            )

        return questions_docs, answers_docs

    def _create_answer_events(
        self,
        game_id: str,
        players_results_docs: list[PlayersResultsDoc],
        questions_settings: dict[str, 'QuestionSettings'],
    ) -> list[AnswerEvent]:
        """Create answer events from players answers docs and questions settings."""
        answer_events = []
        for players_results_doc in players_results_docs:
            question_uid = players_results_doc['question_uid']
            for player_id, player_result in players_results_doc[
                'players_results'
            ].items():
                answer_events.append(
                    AnswerEvent(
                        question_uid=uuid.UUID(question_uid),
                        question_difficulty=questions_settings[question_uid].difficulty,
                        question_category=questions_settings[question_uid].category,
                        user_firebase_id=player_id,
                        game_id=game_id,
                        answer=player_result['answer'],
                        correct_answer=player_result['correct_answer'],
                        score_number=player_result['score']['number'],
                        score_quantile=player_result['score']['quantile'],
                    ),
                )
        return answer_events

    async def archive_game_results(
        self,
        game_id: str,
        players_results_docs: list[PlayersResultsDoc],
        questions_settings: dict[str, 'QuestionSettings'],
    ) -> None:
        """Archive game results to the database.

        Done sequentially to avoid AsyncSession concurrency hazards and to
        guarantee history writes happen after answer events are stored.
        """
        # 1) Add users' answer events
        answer_events = self._create_answer_events(
            game_id=game_id,
            players_results_docs=players_results_docs,
            questions_settings=questions_settings,
        )
        await self._db_client.answers.add_answers(answer_events)

        # 2) Add questions to users' histories
        for players_results_doc in players_results_docs:
            user_ids = list(players_results_doc['players_results'].keys())
            await self._db_client.users_history.add_questions_to_users_history(
                user_ids=user_ids,
                question_uids=(uuid.UUID(players_results_doc['question_uid']),),
            )

    async def get_player_stats(self, player_id: str) -> PlayerStats:
        """Get a player's stats."""
        return PlayerStats(
            player_quantiles=await self._db_client.answers.get_ave_quantile(player_id),
        )

    async def set_user_vote(
        self,
        *,
        question_uid: str,
        user_firebase_uid: str,
        verdict: int,
    ) -> int:
        """Set a user's verdict on a question and update aggregates.

        Returns the resulting verdict value.
        """
        result = await self._db_client.question_votes.set_verdict(
            question_uid=uuid.UUID(question_uid),
            user_firebase_uid=user_firebase_uid,
            verdict=VoteVerdict(verdict),
        )
        return int(result)

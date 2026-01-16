"""Background task: submit bot answers for the current question.

Bots answer instantly when a question is revealed. This task fetches the
LLM answers from the fermi MV and submits them as bot player answers.
Bot answers are NOT stored in answer_events to preserve quantile statistics.
"""

import logging
import uuid
from typing import TYPE_CHECKING, cast

from fermi_db.dal import DatabaseClient
from fermi_db.schemas import AnswerBare
from fermi_db.session import session_context
from google.cloud import firestore

from app.schemas.game import AnswersProgress, GamePlayer, GameState, PlayersResultsDoc
from app.services.game.bots import get_bot_answer
from app.services.game.repositories.game_repo import GameRepository

if TYPE_CHECKING:
    from google.cloud.firestore_v1 import AsyncClient, AsyncTransaction

logger = logging.getLogger(__name__)


async def submit_bot_answers(
    *,
    firestore_client: 'AsyncClient',
    game_id: str,
    question_uid: str,
    bot_ids: list[str],
) -> None:
    """Submit answers for all bots in the game.

    This is a fire-and-forget background task. Bots answer instantly when
    the question is revealed.

    When a bot is the last player to answer (all_answered becomes True),
    this function also handles the reveal logic: finishing the question,
    updating scores/ranks, and revealing results to the frontend.

    Args:
        firestore_client: Firestore client for reading/writing game data.
        game_id: The game ID.
        question_uid: The current question UID.
        bot_ids: List of bot player IDs to submit answers for.

    """
    logger.info(
        f'[Game {game_id}] BOT BACKGROUND TASK STARTED for {len(bot_ids)} bots: '
        f'{bot_ids}',
    )
    from app.services.game.writers.lifecycle_writer import GameLifecycleWriter
    from app.services.game.writers.players_answers_writer import (
        GamePlayersAnswersWriter,
    )
    from app.services.game.writers.players_writer import GamePlayersWriter
    from app.services.game.writers.questions_writer import GameQuestionsWriter

    game_ref = firestore_client.collection('games').document(game_id)
    repo = GameRepository(firestore_client)
    players_answers_writer = GamePlayersAnswersWriter()
    lifecycle_writer = GameLifecycleWriter()
    players_writer = GamePlayersWriter()
    questions_writer = GameQuestionsWriter()

    logger.info(
        f'[Game {game_id}] Submitting bot answers for question {question_uid}: '
        f'{bot_ids}',
    )

    # 1. Fetch fermi row for this question to get LLM answers
    async with session_context() as session:
        db_client = DatabaseClient(session)
        fermi_row = await db_client.fermi.get_by_uid(
            uuid.UUID(question_uid),
        )

    if not fermi_row:
        logger.error(
            f'[Game {game_id}] Question {question_uid} not found in fermi MV',
        )
        return

    # 2. Read game data for correct answer and progress
    correct_answer_doc = await repo.get_correct_answer(
        game_ref=game_ref,
        question_uid=question_uid,
    )

    # 3. Submit each bot's answer using transactions for strong consistency
    async def _submit_bot_answer_txn(
        bot_id: str,
        bot_answer: AnswerBare,
    ) -> None:
        """Submit a single bot answer within a transaction.

        When this bot's answer triggers all_answered=True, also handles the
        reveal logic (finish question, update scores, reveal results).
        """

        @firestore.async_transactional
        async def _txn(transaction: 'AsyncTransaction') -> None:
            # Read game fields inside transaction (strong consistency)
            game_data = await repo.get_game_fields(
                game_ref,
                fields=['progress', 'state', 'players'],
                tx=transaction,
            )
            if not game_data:
                logger.error(f'[Game {game_id}] Game not found')
                return

            progress = cast(AnswersProgress, game_data['progress'])
            state = GameState(int(game_data['state']))
            players = cast(dict[str, GamePlayer], game_data.get('players', {}))

            # Check if bot already answered (shouldn't happen, but be safe)
            if progress['answered'].get(bot_id, False):
                logger.warning(
                    f'[Game {game_id}] Bot {bot_id} already answered, skipping',
                )
                return

            # Read players_results doc for reveal logic (needed if all_answered)
            players_results_doc = await repo.get_players_results_doc(
                game_ref=game_ref,
                question_uid=question_uid,
                tx=transaction,
            )

            # Submit using transaction for atomic read-write
            all_answered, bot_score, bot_result = players_answers_writer.submit_answer(
                game_ref=game_ref,
                writer=transaction,
                player_id=bot_id,
                question_uid=question_uid,
                answer=bot_answer,
                correct_answer_doc=correct_answer_doc,
                progress=progress,
            )

            # If this bot was the last to answer, handle reveal logic
            if all_answered:
                logger.info(
                    f'[Game {game_id}] Bot {bot_id} was last to answer, '
                    f'triggering reveal logic',
                )

                # Collect all scores from players_results (including this bot)
                question_scores: dict[str, float] = {
                    pid: pr['score']['number']
                    for pid, pr in players_results_doc['players_results'].items()
                }
                question_scores[bot_id] = bot_score

                # Update cumulative scores and ranks
                players_writer.update_scores_and_ranks(
                    game_ref=game_ref,
                    writer=transaction,
                    players=players,
                    question_scores=question_scores,
                )

                # Transition game state to finished
                lifecycle_writer.finish_question(
                    game_ref=game_ref,
                    writer=transaction,
                    state=state,
                )

                # Reveal players results (set revealed=True, compute conversions)
                players_answers_writer.reveal_players_results(
                    game_ref=game_ref,
                    writer=transaction,
                    question_uid=question_uid,
                    players_results_doc=cast(PlayersResultsDoc, players_results_doc),
                    current_player_id=bot_id,
                    current_player_result=bot_result,
                )

                # Reveal answer document for answer walkthrough
                questions_writer.reveal_answer(
                    game_ref=game_ref,
                    writer=transaction,
                    question_uid=question_uid,
                )

        transaction = firestore_client.transaction()
        await _txn(transaction)

    for bot_id in bot_ids:
        try:
            bot_answer = get_bot_answer(fermi_row, bot_id)
            logger.debug(
                f'[Game {game_id}] Bot {bot_id} answering: {bot_answer}',
            )

            await _submit_bot_answer_txn(bot_id, bot_answer)

            logger.info(
                f'[Game {game_id}] ✅ Bot {bot_id} submitted answer successfully',
            )

        except Exception as exc:
            logger.error(
                f'[Game {game_id}] ❌ Failed to submit bot {bot_id} answer: {exc}',
                exc_info=True,
            )

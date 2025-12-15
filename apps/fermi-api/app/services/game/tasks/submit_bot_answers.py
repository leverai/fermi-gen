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

from app.schemas.game import AnswersProgress
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

    Args:
        firestore_client: Firestore client for reading/writing game data.
        game_id: The game ID.
        question_uid: The current question UID.
        bot_ids: List of bot player IDs to submit answers for.

    """
    logger.info(
        f'[Game {game_id}] BOT BACKGROUND TASK STARTED for {len(bot_ids)} bots: {bot_ids}',
    )
    from app.services.game.writers.players_answers_writer import (
        GamePlayersAnswersWriter,
    )

    game_ref = firestore_client.collection('games').document(game_id)
    repo = GameRepository(firestore_client)
    players_answers_writer = GamePlayersAnswersWriter()

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
        """Submit a single bot answer within a transaction."""

        @firestore.async_transactional
        async def _txn(transaction: 'AsyncTransaction') -> None:
            # Read progress inside transaction (strong consistency)
            game_data = await repo.get_game_fields(
                game_ref,
                fields=['progress'],
                tx=transaction,
            )
            if not game_data:
                logger.error(f'[Game {game_id}] Game not found')
                return

            progress = cast(AnswersProgress, game_data['progress'])

            # Check if bot already answered (shouldn't happen, but be safe)
            if progress['answered'].get(bot_id, False):
                logger.warning(
                    f'[Game {game_id}] Bot {bot_id} already answered, skipping',
                )
                return

            # Submit using transaction for atomic read-write
            players_answers_writer.submit_answer(
                game_ref=game_ref,
                writer=transaction,
                player_id=bot_id,
                question_uid=question_uid,
                answer=bot_answer,
                correct_answer_doc=correct_answer_doc,
                progress=progress,
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

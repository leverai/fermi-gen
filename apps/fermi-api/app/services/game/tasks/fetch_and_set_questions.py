"""Background task: fetch questions and attach them to a game.

This task mirrors the previous in-class method but is extracted to a dedicated
module so it can be scheduled post-commit by use cases or services.

Important: this task manages its own database session using
``fermi_db.session.session_context`` to avoid reusing request-scoped DI
sessions, which can lead to connection leaks or hangs during teardown.
"""

import logging
from typing import TYPE_CHECKING

from fermi_db.dal import DatabaseClient
from fermi_db.session import session_context

from app.services.game.gateways.analytics_gateway import GameAnalyticsGateway

logger = logging.getLogger(__name__)

if TYPE_CHECKING:
    from google.cloud.firestore_v1 import AsyncDocumentReference, AsyncWriteBatch

    from app.schemas.endpoints import QuestionRoundSettings
    from app.services.game.gateways.analytics_gateway import GameAnalyticsGateway
    from app.services.game.writers.lifecycle_writer import GameLifecycleWriter
    from app.services.game.writers.players_answers_writer import (
        GamePlayersAnswersWriter,
    )
    from app.services.game.writers.questions_writer import GameQuestionsWriter


async def fetch_and_set_questions(
    *,
    lifecycle: 'GameLifecycleWriter',
    players_answers: 'GamePlayersAnswersWriter',
    questions: 'GameQuestionsWriter',
    game_ref: 'AsyncDocumentReference',
    batch: 'AsyncWriteBatch',
    user_ids: list[str],
    question_round_settings: 'QuestionRoundSettings',
    version_uid: str,
) -> None:
    """Fetch questions, set them in the game, initialize results and mark ready.

    Commits only if the provided ``version_uid`` matches the one in Firestore to
    avoid racing with subsequent re-initializations.
    """
    game_id = game_ref.id
    logger.info(
        f'[Game {game_id}] Starting fetch_and_set_questions (version={version_uid})',
    )

    # 1) Create an isolated DB session/gateway and fetch questions/answers
    logger.debug(f'[Game {game_id}] Fetching questions from database...')
    async with session_context() as session:
        db_manager = GameAnalyticsGateway(db_client=DatabaseClient(session))
        (
            questions_docs,
            answers_docs,
        ) = await db_manager.get_questions_and_answers_docs(
            question_round_settings=question_round_settings,
            user_ids=user_ids,
        )
    logger.info(
        f'[Game {game_id}] Fetched {len(questions_docs)} questions successfully',
    )

    # 2) Set questions docs, answers docs, and question_uids
    question_uids = questions.set_questions(
        game_ref=game_ref,
        writer=batch,
        questions_docs=questions_docs,
        answers_docs=answers_docs,
        request_categories=question_round_settings.categories,
        game_difficulty=question_round_settings.difficulty,
    )
    logger.debug(f'[Game {game_id}] Set question_uids: {question_uids}')

    # 3) Init players answers docs
    players_answers.init_players_results_docs(
        game_ref=game_ref,
        writer=batch,
        question_uids=question_uids,
    )

    # 4) Update game state to ready
    lifecycle.set_ready(game_ref=game_ref, writer=batch)

    # 5) Commit if version_uids match
    game_snapshot = await game_ref.get(['version_uid'])
    current_version = game_snapshot.get('version_uid')

    if version_uid == current_version:
        # See original note about the small race window. Acceptable for now.
        await batch.commit()
        logger.info(
            f'[Game {game_id}] ✅ Successfully committed batch - '
            f'game is now LOBBY_READY',
        )
    else:
        # Version mismatch means another operation changed it (e.g., player joined)
        # This is EXPECTED behavior - the newer operation will trigger its own fetch
        logger.warning(
            f'[Game {game_id}] ⚠️  Version mismatch - batch NOT committed. '
            f'Expected version={version_uid}, current version={current_version}. '
            f'This is normal when a player joins during question fetch.',
        )

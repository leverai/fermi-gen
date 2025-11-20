"""Background task: archive finished game results to the analytics database.

Separates post-commit archiving from transactional logic. Reads are performed
via ``GameRepository`` to gather the minimal required information, then data is
persisted using ``GameDbManager``.

Important: this task manages its own database session using
``fermi_db.session.session_context`` to avoid reusing request-scoped DI
sessions, which can lead to connection leaks or hangs during teardown.
"""

from typing import TYPE_CHECKING, cast

from fermi_db.dal import DatabaseClient
from fermi_db.session import session_context

from app.services.game.gateways.analytics_gateway import GameAnalyticsGateway

if TYPE_CHECKING:
    from google.cloud.firestore_v1 import AsyncClient

    from app.services.game.gateways.analytics_gateway import GameAnalyticsGateway
    from app.services.game.repositories.game_repo import GameRepository


async def archive_game_results(
    *,
    firestore_client: 'AsyncClient',
    repo: 'GameRepository',
    game_id: str,
) -> None:
    """Archive results for ``game_id`` if there are any to persist."""
    game_ref = firestore_client.collection('games').document(game_id)

    # Read question metadata required for archiving
    archive_fields = await repo.get_game_fields(
        game_ref,
        fields=['question_uids', 'category', 'difficulty'],
    )
    question_uids = cast(list[str] | None, archive_fields.get('question_uids'))
    if not question_uids:
        return

    # Fetch per-question settings and players' results
    questions_settings = await repo.get_questions_settings(
        game_ref=game_ref,
        question_uids=question_uids,
    )
    players_results_docs = await repo.get_players_results_docs(
        game_ref=game_ref,
        question_uids=question_uids,
    )

    if not players_results_docs:
        return

    async with session_context() as session:
        db_gateway = GameAnalyticsGateway(db_client=DatabaseClient(session))
        await db_gateway.archive_game_results(
            game_id=game_id,
            players_results_docs=players_results_docs,
            questions_settings=questions_settings,
        )

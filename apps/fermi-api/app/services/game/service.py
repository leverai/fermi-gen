"""Game service."""

import logging
from typing import TYPE_CHECKING

from fastapi import Request

from app.schemas.endpoints import (
    GameConfigResponse,
    GetPlayerStatsResponse,
    PlayerStats,
    UserLimits,
)
from app.services.game.gateways.analytics_gateway import GameAnalyticsGateway
from app.services.game.ranks import get_all_ranks, get_rank_for_percentile
from app.services.game.utils import get_request_categories, get_request_difficulties

if TYPE_CHECKING:
    from fermi_db import DatabaseClient
    from fermi_db.repositories.precision_rush_run_repository import (
        PrecisionRushRunRepository,
    )
    from fermi_db.repositories.survival_run_repository import SurvivalRunRepository
    from google.cloud.firestore_v1 import (
        AsyncClient,
    )

# Free tier survival run limit (per calendar day)
FREE_SURVIVAL_RUNS_PER_DAY = 2

# Free tier precision rush run limit (per calendar day)
FREE_PRECISION_RUSH_RUNS_PER_DAY = 1


class GameService:
    """Service for game-related operations."""

    def __init__(self, db_client: 'DatabaseClient') -> None:
        """Initialize the game service."""
        self._db_gateway = GameAnalyticsGateway(db_client=db_client)

    async def get_player_stats(
        self,
        player_id: str,
        request: Request | None = None,
    ) -> GetPlayerStatsResponse:
        """Get a player's stats."""
        raw_stats = await self._db_gateway.get_player_stats(
            player_id=player_id,
        )
        rank = get_rank_for_percentile(
            avg_percentile=raw_stats['average_percentile'],
            request=request,
        )
        return GetPlayerStatsResponse(
            player_id=player_id,
            stats=PlayerStats(
                total_party_games=0,
                total_daily_guesses=raw_stats['total_daily_guesses'],
                average_percentile=raw_stats['average_percentile'],
                total_survival_runs=raw_stats['total_survival_runs'],
                rank=rank,
                xp=raw_stats['xp'],
                level=raw_stats['level'],
                points=raw_stats['points'],
            ),
        )

    async def get_game_config(
        self,
        request: Request | None = None,
    ) -> GameConfigResponse:
        """Get the game config.

        This returns static game configuration that never changes per user.
        It should be called once at startup and cached.

        Args:
            request: FastAPI request for building asset URLs.

        Returns:
            Static game config (categories, difficulties, ranks).

        """
        return GameConfigResponse(
            categories=get_request_categories(),
            difficulties=get_request_difficulties(request),
            ranks=get_all_ranks(request),
        )

    async def get_user_limits(
        self,
        *,
        user_id: int,
        user_firebase_uid: str,
        survival_run_repo: 'SurvivalRunRepository',
        precision_rush_run_repo: 'PrecisionRushRunRepository',
        is_pro: bool = False,
    ) -> UserLimits:
        """Get user-specific limits based on subscription tier.

        Args:
            user_id: User's database ID.
            user_firebase_uid: User's Firebase UID.
            survival_run_repo: Repository for checking survival run limits.
            precision_rush_run_repo: Repository for checking precision rush limits.
            is_pro: Whether user has Pro subscription.

        Returns:
            User limits including remaining survival runs and precision rush runs.

        """
        survival_left = (
            -1
            if is_pro
            else await survival_run_repo.get_runs_remaining_today(
                user_firebase_uid=user_firebase_uid,
                limit=FREE_SURVIVAL_RUNS_PER_DAY,
            )
        )
        pr_left = (
            -1
            if is_pro
            else await precision_rush_run_repo.get_runs_remaining_today(
                user_firebase_uid=user_firebase_uid,
                limit=FREE_PRECISION_RUSH_RUNS_PER_DAY,
            )
        )
        return UserLimits(
            party_hostings_remaining=0,  # Party mode removed
            survival_runs_remaining=survival_left,
            precision_rush_runs_remaining=pr_left,
        )

    async def vote(
        self,
        *,
        question_uid: str,
        user_firebase_uid: str,
        verdict: int,
    ) -> int:
        """Set a user's vote verdict and return the resulting verdict."""
        return await self._db_gateway.set_user_vote(
            question_uid=question_uid,
            user_firebase_uid=user_firebase_uid,
            verdict=verdict,
        )

    async def cleanup_finished_games(
        self,
        firestore_client: 'AsyncClient',
        *,
        max_games: int = 100,
    ) -> int:
        """Delete finished/aborted games and their subcollections.

        Games with state >= 8 (GAME_FINISHED or GAME_ABORTED) are eligible
        for deletion. Subcollections (questions, answers, players_results)
        are deleted before the parent game document.

        Args:
            firestore_client: Firestore async client.
            max_games: Maximum number of games to delete in this call.

        Returns:
            Number of games deleted.

        """
        logger = logging.getLogger(__name__)
        games_ref = firestore_client.collection('games')

        # Query for finished/aborted games (state >= 8)
        query = games_ref.where('state', '>=', 8).limit(max_games)
        game_docs = [doc async for doc in query.stream()]

        deleted_count = 0
        for game_doc in game_docs:
            game_ref = games_ref.document(game_doc.id)

            # Delete subcollection documents
            for subcollection_name in ('questions', 'answers', 'players_results'):
                subcollection_ref = game_ref.collection(subcollection_name)
                async for sub_doc in subcollection_ref.stream():
                    await sub_doc.reference.delete()

            # Delete the game document itself
            await game_ref.delete()
            deleted_count += 1

        logger.info('Deleted %d finished/aborted games', deleted_count)
        return deleted_count

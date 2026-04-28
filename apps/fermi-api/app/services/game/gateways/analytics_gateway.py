"""Gateway to the analytics database.

This module serves as an adapter to the Postgres-based analytics and history
database. It fetches raw data from the database, converts it to domain-specific
documents, and archives game results. It is designed to be a pure adapter and
has no knowledge of Firestore or HTTP semantics.
"""

import uuid
from typing import TYPE_CHECKING

from fermi_db.models.game import VoteVerdict

if TYPE_CHECKING:
    from fermi_db import DatabaseClient


class GameAnalyticsGateway:
    """Gateway for game-related analytics and history database operations.

    This class is a pure adapter to the Postgres DAL. It does not know about
    HTTP or Firestore.
    """

    def __init__(self, db_client: 'DatabaseClient') -> None:
        """Initialize the game analytics gateway."""
        self._db_client = db_client

    async def get_player_stats(self, player_id: str) -> dict:
        """Get a player's raw stats.

        Returns a dict containing:
            - total_daily_guesses: int
            - average_percentile: int
            - xp: int
            - level: int (computed from xp)
            - points: int
        """
        avg_pct = await self._db_client.answers.get_overall_avg_percentile(
            player_id,
        )
        xp = await self._db_client.users.get_xp(player_id)
        level = (xp // 100) + 1
        points = await self._db_client.users.get_points(player_id)
        return {
            'total_daily_guesses': await self._db_client.dq_answers.count_user_answers(
                player_id,
            ),
            'total_survival_runs': await self._db_client.survival_runs.count_user_survival_runs(  # noqa: E501
                player_id,
            ),
            'average_percentile': avg_pct,
            'xp': xp,
            'level': level,
            'points': points,
        }

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

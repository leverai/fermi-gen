"""Repository for party game hosting records."""

import datetime

from sqlmodel import func, select

from fermi_db.models.game import PartyGameHosting

from . import BaseRepository


class PartyHostingRepository(BaseRepository):
    """Repository for party game hosting records.

    Used for tracking and enforcing free tier party hosting limits.
    """

    async def record_hosting(self, user_id: int, game_id: str) -> None:
        """Record a new party game hosting.

        Args:
            user_id: The user's database ID.
            game_id: The Firestore game document ID.

        """
        hosting = PartyGameHosting(user_id=user_id, game_id=game_id)
        self.session.add(hosting)
        await self.session.commit()

    async def count_week_hostings(self, user_id: int) -> int:
        """Count hostings for a user in the current calendar week (Mon-Sun UTC).

        Calendar week starts Monday 00:00:00 UTC and ends Sunday 23:59:59 UTC.

        Args:
            user_id: The user's database ID.

        Returns:
            Number of hostings this calendar week.

        """
        week_start = self._get_week_start_utc()
        stmt = select(func.count(PartyGameHosting.id)).where(  # type: ignore
            PartyGameHosting.user_id == user_id,
            PartyGameHosting.created_at >= week_start,
        )
        result = await self.session.execute(stmt)
        return result.scalar() or 0

    async def get_hostings_remaining(self, user_id: int, limit: int) -> int:
        """Get remaining hostings for a user this calendar week.

        Args:
            user_id: The user's database ID.
            limit: Maximum hostings allowed per week.

        Returns:
            Number of hostings remaining (0 if at limit).

        """
        count = await self.count_week_hostings(user_id)
        return max(0, limit - count)

    @staticmethod
    def _get_week_start_utc() -> datetime.datetime:
        """Get the start of the current calendar week (Monday 00:00 UTC).

        Returns:
            datetime at Monday 00:00:00 of the current week.

        """
        now = datetime.datetime.now(datetime.UTC).replace(tzinfo=None)
        # weekday(): Monday=0, Sunday=6
        days_since_monday = now.weekday()
        week_start = now - datetime.timedelta(days=days_since_monday)
        return week_start.replace(hour=0, minute=0, second=0, microsecond=0)

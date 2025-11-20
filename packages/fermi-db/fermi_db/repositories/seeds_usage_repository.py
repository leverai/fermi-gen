"""Repository for seeds usage tracking and statistics."""

from typing import cast

from pydantic import BaseModel
from sqlalchemy import func
from sqlmodel import select

from fermi_db.models import Seed, SeedsUsage
from fermi_db.repositories import BaseRepository


class SeedStats(BaseModel):
    """Aggregated statistics for a seed (for Thompson Sampling)."""

    seed_id: int
    total_requested: int
    total_yielded: int
    alpha: float  # Successes + 1 (for Beta distribution)
    beta: float  # Failures + 1 (for Beta distribution)


class SeedsUsageRepository(BaseRepository):
    """Handle database operations for seeds usage tracking."""

    async def record_usage(
        self,
        seed_id: int,
        requested: int,
        generated: int,
    ) -> int:
        """Record a new usage batch for a seed.

        Args:
            seed_id: The seed that was used
            requested: Number of questions requested from LLM
            generated: Number of questions LLM actually generated

        Returns:
            The ID of the created usage record

        """
        usage = SeedsUsage(
            seed_id=seed_id,
            requested=requested,
            generated=generated,
            yielded=None,  # Will be updated after dedup
        )
        self.session.add(usage)
        await self.session.commit()
        await self.session.refresh(usage)
        return usage.id  # type: ignore

    async def update_yielded(self, usage_id: int, yielded: int) -> None:
        """Update the yielded count after deduplication.

        Args:
            usage_id: ID of the usage record to update
            yielded: Number of unique questions after dedup

        """
        statement = select(SeedsUsage).where(SeedsUsage.id == usage_id)
        result = await self.session.exec(statement)
        usage = result.one()

        usage.yielded = yielded
        self.session.add(usage)
        await self.session.commit()

    async def get_aggregated_stats(self) -> list[SeedStats]:
        """Get aggregated statistics for ALL seeds (for Thompson Sampling).

        Returns stats for all seeds in the database. Seeds without usage history
        get a uniform prior (alpha=1, beta=1) representing complete uncertainty.
        This ensures Thompson Sampling can explore new seeds.

        Computes:
        - total_requested: sum of all requested questions per seed (0 if never used)
        - total_yielded: sum of all yielded questions per seed (0 if never used)
        - alpha: total_yielded + 1 (successes for Beta distribution)
        - beta: (total_requested - total_yielded) + 1 (failures for Beta)

        Returns:
            List of SeedStats for ALL seeds

        """
        # Subquery: aggregate usage stats per seed
        usage_subquery = (
            select(
                SeedsUsage.seed_id,
                func.sum(SeedsUsage.requested).label('total_requested'),
                func.coalesce(func.sum(SeedsUsage.yielded), 0).label('total_yielded'),
            )
            .where(SeedsUsage.yielded.is_not(None))  # type: ignore
            .group_by(SeedsUsage.seed_id)  # type: ignore
            .subquery()
        )

        # Main query: all seeds, left join with usage stats
        statement = (
            select(
                Seed.id,
                func.coalesce(usage_subquery.c.total_requested, 0).label(
                    'total_requested',
                ),
                func.coalesce(usage_subquery.c.total_yielded, 0).label('total_yielded'),
            ).outerjoin(usage_subquery, Seed.id == usage_subquery.c.seed_id)  # type: ignore
        )

        result = await self.session.exec(statement)
        stats = []
        for row in result.all():
            seed_id, total_requested, total_yielded = row
            # Thompson Sampling: Beta(alpha, beta) distribution
            # Unused seeds get uniform prior: Beta(1, 1)
            alpha = float(total_yielded) + 1.0
            beta = float(total_requested - total_yielded) + 1.0
            stats.append(
                SeedStats(
                    seed_id=cast(int, seed_id),
                    total_requested=int(total_requested),
                    total_yielded=int(total_yielded),
                    alpha=alpha,
                    beta=beta,
                ),
            )
        return stats

    async def get_least_recently_used_seeds(self, limit: int) -> list[int]:
        """Get seed IDs that were least recently used (for explore mode).

        Args:
            limit: Maximum number of seed IDs to return

        Returns:
            List of seed IDs ordered by least recent usage

        """
        # Subquery to get the latest usage timestamp for each seed
        latest_usage_subquery = (
            select(
                SeedsUsage.seed_id,
                func.max(SeedsUsage.created_at).label('last_used'),
            )
            .group_by(SeedsUsage.seed_id)  # type: ignore
            .subquery()
        )

        # Get all seeds and join with latest usage
        statement = (
            select(Seed.id)
            .outerjoin(
                latest_usage_subquery,
                Seed.id == latest_usage_subquery.c.seed_id,  # type: ignore
            )
            .order_by(
                latest_usage_subquery.c.last_used.nulls_first(),  # type: ignore
                Seed.created_at,  # type: ignore
            )
            .limit(limit)
        )

        result = await self.session.exec(statement)
        return cast(list[int], result.all())
